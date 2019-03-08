//
//  Server.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation
import Base
import NIO
import NIOHTTP1
import NIOFoundationCompat
import Promise


public typealias HTTPResponseStatus = NIOHTTP1.HTTPResponseStatus

public protocol Response {
    static func write(_ string: String, status: HTTPResponseStatus, headers: [String: String]) -> Self
    static func write(_ data: Data, status: HTTPResponseStatus, headers: [String: String]) -> Self
    static func writeFile(path: String, maxAge: UInt64?) -> Self
    static func redirect(path: String, headers: [String: String]) -> Self
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> Self) -> Self
    static func withPostData(do cont: @escaping (Data) -> Self) -> Self
}

public struct NIOInterpreter: Response {
    struct Deps {
        let request: HTTPRequestHead
        let ctx: ChannelHandlerContext
        let fileIO: NonBlockingFileIO
        let handler: RouteHandler
        let manager: FileManager
        let resourcePaths: [URL]
    }
    let run: (Deps) -> PostContinuation?
    public typealias PostContinuation = (Data) -> NIOInterpreter
    
    public static func withPostData(do cont: @escaping PostContinuation) -> NIOInterpreter {
        return NIOInterpreter { env in
            return cont
        }
    }

    public static func redirect(path: String, headers: [String: String] = [:]) -> NIOInterpreter {
        return NIOInterpreter { env in
            // We're using seeOther (303) because it won't do a POST but always a GET (important for forms)
            var head = HTTPResponseHead(version: env.request.version, status: .seeOther)
            head.headers.add(name: "Location", value: path)
            for (key, value) in headers {
                head.headers.add(name: key, value: value)
            }
            let part = HTTPServerResponsePart.head(head)
            _ = env.ctx.channel.write(part)
            completeResponse(env)
            return nil
        }
    }
    
    public static func writeFile(path: String, maxAge: UInt64? = 60) -> NIOInterpreter {
        return NIOInterpreter { env in
            let fullPath = env.resourcePaths.resolve(path) ?? URL(fileURLWithPath: "")
            let fileHandleAndRegion = env.fileIO.openFile(path: fullPath.path, eventLoop: env.ctx.eventLoop)
            fileHandleAndRegion.whenFailure { _ in
                _ = write("Error", status: .badRequest).run(env)
            }
            fileHandleAndRegion.whenSuccess { (file, region) in
                var response = HTTPResponseHead(version: env.request.version, status: .ok)
                response.headers.add(name: "Content-Length", value: "\(region.endIndex)")
                let contentType: String
                // (path as NSString) doesn't work on Linux... so using the initializer below.
                switch NSString(string: path).pathExtension {
                case "css": contentType = "text/css; charset=utf-8"
                case "svg": contentType = "image/svg+xml; charset=utf8"
                default: contentType = "text/plain; charset=utf-8"
                }
                response.headers.add(name: "Content-Type", value: contentType)
                if let m = maxAge {
                	response.headers.add(name: "Cache-Control", value: "max-age=\(m)")
                }
                env.ctx.write(env.handler.wrapOutboundOut(.head(response)), promise: nil)
                env.ctx.writeAndFlush(env.handler.wrapOutboundOut(.body(.fileRegion(region)))).then {
                    let p: EventLoopPromise<Void> = env.ctx.eventLoop.newPromise()
                    completeResponse(env, promise: p)
                    return p.futureResult
                }.thenIfError { (_: Error) in
                    env.ctx.close()
                }.whenComplete {
                    _ = try? file.close()
                }
            }
            return nil
        }
    }
    
    public static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> NIOInterpreter) -> NIOInterpreter {
        return NIOInterpreter { env in
            promise.run { str in
                env.ctx.eventLoop.execute {
                    let result = cont(str).run(env)
                    assert(result == nil, "You have to read POST data as the first step")
                }

            }
            return nil
        }
    }
    
    public static func write(_ data: Data, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> NIOInterpreter {
        return NIOInterpreter { env in
            var head = HTTPResponseHead(version: env.request.version, status: status)
            for (key, value) in headers {
                head.headers.add(name: key, value: value)
            }
            let part = HTTPServerResponsePart.head(head)
            _ = env.ctx.channel.write(part)
            var buffer = env.ctx.channel.allocator.buffer(capacity: data.count)
            buffer.write(bytes: data)
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = env.ctx.channel.write(bodyPart)
            completeResponse(env)
            return nil
        }
    }

    public static func write(_ string: String, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> NIOInterpreter {
        return NIOInterpreter { env in
            let head = httpResponseHead(request: env.request, status: status, headers: HTTPHeaders(headers.map { ($0, $1) }))
            let part = HTTPServerResponsePart.head(head)
            _ = env.ctx.channel.write(part)
            var buffer = env.ctx.channel.allocator.buffer(capacity: string.utf8.count)
            buffer.write(string: string)
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = env.ctx.channel.write(bodyPart)
            completeResponse(env)
            return nil
        }
    }
    
    private static func completeResponse(_ env: Deps, promise: EventLoopPromise<Void>? = nil) {
        let promise = env.request.isKeepAlive ? promise : (promise ?? env.ctx.eventLoop.newPromise())
        if !env.request.isKeepAlive {
            promise!.futureResult.whenComplete { env.ctx.close(promise: nil) }
        }
        _ = env.ctx.channel.writeAndFlush(env.handler.wrapOutboundOut(.end(nil)), promise: promise)
    }
}

// This code is taken from the Swift NIO project: https://github.com/apple/swift-nio/blob/nio-1.13/Sources/NIOHTTP1Server/main.swift#L36
private func httpResponseHead(request: HTTPRequestHead, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders()) -> HTTPResponseHead {
    var head = HTTPResponseHead(version: request.version, status: status, headers: headers)
    let connectionHeaders: [String] = head.headers[canonicalForm: "connection"].map { $0.lowercased() }
    
    if !connectionHeaders.contains("keep-alive") && !connectionHeaders.contains("close") {
        // the user hasn't pre-set either 'keep-alive' or 'close', so we might need to add headers
        switch (request.isKeepAlive, request.version.major, request.version.minor) {
        case (true, 1, 0):
            // HTTP/1.0 and the request has 'Connection: keep-alive', we should mirror that
            head.headers.add(name: "Connection", value: "keep-alive")
        case (false, 1, let n) where n >= 1:
            // HTTP/1.1 (or treated as such) and the request has 'Connection: close', we should mirror that
            head.headers.add(name: "Connection", value: "close")
        default:
            // we should match the default or are dealing with some HTTP that we don't support, let's leave as is
            ()
        }
    }
    return head
}

extension Base.HTTPMethod {
    init?(_ value: NIOHTTP1.HTTPMethod) {
        switch value {
        case .GET: self = .get
        case .POST: self = .post
        default: return nil
        }
    }
}



final class RouteHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    let handle: (Request) -> NIOInterpreter?
    let paths: [URL]
    var postCont: (NIOInterpreter.PostContinuation, HTTPRequestHead)? = nil
    var accumData = Data()
    
    let fileIO: NonBlockingFileIO
    init(_ fileIO: NonBlockingFileIO, resourcePaths: [URL], handle: @escaping (Request) -> NIOInterpreter?) {
        self.fileIO = fileIO
        self.handle = handle
        self.paths = resourcePaths
    }
    
    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        log(info: "Error caught: \(error)")
        ctx.close(promise: nil)
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        switch reqPart {
        case .head(let header):
            accumData = Data()
            
            let cookies = header.headers["Cookie"].first.map {
                $0.split(separator: ";").compactMap { $0.trimmingCharacters(in: .whitespaces).keyAndValue }
            } ?? []
            let env = NIOInterpreter.Deps(request: header, ctx: ctx, fileIO: fileIO, handler: self, manager: FileManager.default, resourcePaths: paths)

            func notFound() {
                log(info: "Not found: \(header.uri), method: \(header.method)")
                _ = NIOInterpreter.write("Not found: \(header.uri)", status: .notFound).run(env)
            }
            
            guard let method = HTTPMethod(header.method) else { notFound(); return }
            let r = Request(header.uri, method: method, cookies: cookies)
            if let i = handle(r) {
                if let c = i.run(env) {
                    postCont = (c, header)
                }
            } else {
                notFound()
            }

        case .body(var b):
            guard postCont != nil else { return }
            if let d = b.readData(length: b.readableBytes) {
                accumData.append(d)
            }
        case .end:
            if let (p, header) = postCont {
                let env = NIOInterpreter.Deps(request: header, ctx: ctx, fileIO: fileIO, handler: self, manager: FileManager.default, resourcePaths: paths)
                let result = p(accumData).run(env)
                accumData = Data()
                assert(result == nil, "Can't read post data twice")
            }
        }
    }
}



public struct Server {
    let threadPool: BlockingIOThreadPool = {
        let t = BlockingIOThreadPool(numberOfThreads: 1)
        t.start()
        return t
    }()
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private let fileIO: NonBlockingFileIO
    private let handle: (Request) -> NIOInterpreter?
    private let paths: [URL]

    public init(resourcePaths: [URL], handle: @escaping (Request) -> NIOInterpreter?) {
        fileIO = NonBlockingFileIO(threadPool: threadPool)
        self.handle = handle
        paths = resourcePaths
    }
    
    func execute(_ f: @escaping () -> ()) {
        group.next().execute(f)
    }
    
    public func listen(port: Int = 8765) throws {
        let reuseAddr = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),
                                              SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(reuseAddr, value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).then { _ in
                    channel.pipeline.add(handler: RouteHandler(self.fileIO, resourcePaths: self.paths, handle: self.handle))
                }
            }
            .childChannelOption(ChannelOptions.socket(
                IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(reuseAddr, value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead,
                                value: 1)
        log(info: "Going to start listening on port \(port)")
        let channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
        try channel.closeFuture.wait()
    }
}
