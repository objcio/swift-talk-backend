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
    static func writeFile(path: String, gzipped: String?, maxAge: UInt64?) -> Self
    static func redirect(path: String, headers: [String: String]) -> Self
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> Self) -> Self
    static func withPostData(do cont: @escaping (Data) -> Self) -> Self
}

public struct NIOInterpreter: Response {
    struct Deps {
        let header: HTTPRequestHead
        let context: ChannelHandlerContext
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
            var head = HTTPResponseHead(version: env.header.version, status: .seeOther)
            head.headers.add(name: "Location", value: path)
            for (key, value) in headers {
                head.headers.add(name: key, value: value)
            }
            let part = HTTPServerResponsePart.head(head)
            _ = env.context.channel.write(part)
            _ = env.context.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).flatMap {
                env.context.channel.close()
            }
            return nil
        }
    }
    
    public static func writeFile(path original: String, gzipped: String?, maxAge: UInt64? = 60) -> NIOInterpreter {
        return NIOInterpreter { deps in
            let acceptsGzip = deps.header.headers["Accept-Encoding"].joined(separator: ",").contains("gzip")
            let willSendGzipped = acceptsGzip && gzipped != nil
            let path = (acceptsGzip ? gzipped : nil) ?? original
            let fullPath = deps.resourcePaths.resolve(path) ?? URL(fileURLWithPath: "")
            let fileHandleAndRegion = deps.fileIO.openFile(path: fullPath.path, eventLoop: deps.context.eventLoop)
            fileHandleAndRegion.whenFailure { _ in
                _ = write("Error", status: .badRequest).run(deps)
            }
            fileHandleAndRegion.whenSuccess { (file, region) in
                var response = HTTPResponseHead(version: deps.header.version, status: .ok)
                response.headers.add(name: "Content-Length", value: "\(region.endIndex)")
                if willSendGzipped {
                    response.headers.add(name: "Content-Encoding", value: "gzip")
                }
                let contentType: String
                // (path as NSString) doesn't work on Linux... so using the initializer below.
                switch NSString(string: original).pathExtension {
                case "css": contentType = "text/css; charset=utf-8"
                case "svg": contentType = "image/svg+xml; charset=utf8"
                default: contentType = "text/plain; charset=utf-8"
                }
                response.headers.add(name: "Content-Type", value: contentType)
                if let m = maxAge {
                	response.headers.add(name: "Cache-Control", value: "max-age=\(m)")
                }
                deps.context.write(deps.handler.wrapOutboundOut(.head(response)), promise: nil)
                deps.context.writeAndFlush(deps.handler.wrapOutboundOut(.body(.fileRegion(region)))).flatMap {
                    let p: EventLoopPromise<Void> = deps.context.eventLoop.makePromise()
                    deps.context.writeAndFlush(deps.handler.wrapOutboundOut(.end(nil)), promise: p)
                    
                    return p.futureResult
                    }.flatMapError { (_: Error) in
                        deps.context.close()
                    }.whenComplete { _ in
                        _ = try? file.close()
                }
            }
            return nil
        }
    }
    
    public static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> NIOInterpreter) -> NIOInterpreter {
        return NIOInterpreter { env in
            promise.run { str in
                env.context.eventLoop.execute {
                    let result = cont(str).run(env)
                    assert(result == nil, "You have to read POST data as the first step")
                }

            }
            return nil
        }
    }
    
    public static func write(_ data: Data, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> NIOInterpreter {
        return NIOInterpreter { env in
            var head = HTTPResponseHead(version: env.header.version, status: status)
            for (key, value) in headers {
                head.headers.add(name: key, value: value)
            }
            let part = HTTPServerResponsePart.head(head)
            _ = env.context.channel.write(part)
            var buffer = env.context.channel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = env.context.channel.write(bodyPart)
            _ = env.context.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).flatMap {
                env.context.channel.close()
            }
            return nil
        }
    }

    public static func write(_ string: String, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> NIOInterpreter {
        return NIOInterpreter { env in
            var head = HTTPResponseHead(version: env.header.version, status: status)
            for (key, value) in headers {
                head.headers.add(name: key, value: value)
            }
            let part = HTTPServerResponsePart.head(head)
            _ = env.context.channel.write(part)
            var buffer = env.context.channel.allocator.buffer(capacity: string.utf8.count)
            buffer.writeString(string)
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = env.context.channel.write(bodyPart)
            _ = env.context.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).flatMap {
                env.context.channel.close()
            }
            return nil
        }
    }
}

extension Base.HTTPMethod {
    init?(_ value: NIOHTTP1.HTTPMethod) {
        switch value {
        case .GET: self = .get
        case .POST: self = .post
        case .HEAD: self = .head
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
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        log(info: "Error caught: \(error)")
        context.close(promise: nil)
    }
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        switch reqPart {
        case .head(let header):
            accumData = Data()
            
            let cookies = header.headers["Cookie"].first.map {
                $0.split(separator: ";").compactMap { $0.trimmingCharacters(in: .whitespaces).keyAndValue }
            } ?? []
            let env = NIOInterpreter.Deps(header: header, context: context, fileIO: fileIO, handler: self, manager: FileManager.default, resourcePaths: paths)

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
                let env = NIOInterpreter.Deps(header: header, context: context, fileIO: fileIO, handler: self, manager: FileManager.default, resourcePaths: paths)
                let result = p(accumData).run(env)
                accumData = Data()
                assert(result == nil, "Can't read post data twice")
            }
        }
    }
}



public struct Server {
    let threadPool: NIOThreadPool = {
        let t = NIOThreadPool(numberOfThreads: 1)
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
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { _ in
                    channel.pipeline.addHandler(RouteHandler(self.fileIO, resourcePaths: self.paths, handle: self.handle))
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
