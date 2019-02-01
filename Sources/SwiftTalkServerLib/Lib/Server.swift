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


protocol Interpreter {
    static func write(_ string: String, status: HTTPResponseStatus, headers: [String: String]) -> Self
    static func write(_ data: Data, status: HTTPResponseStatus, headers: [String: String]) -> Self
    static func writeFile(path: String, maxAge: UInt64?) -> Self
    static func redirect(path: String, headers: [String: String]) -> Self
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> Self) -> Self
    static func withPostData(do cont: @escaping (Data) -> Self) -> Self
}

struct NIOInterpreter: Interpreter {
    struct Deps {
        let header: HTTPRequestHead
        let ctx: ChannelHandlerContext
        let fileIO: NonBlockingFileIO
        let handler: RouteHandler
        let manager: FileManager
        let resourcePaths: [URL]
    }
    let run: (Deps) -> PostContinuation?
    typealias PostContinuation = (Data) -> NIOInterpreter
    
    static func withPostData(do cont: @escaping PostContinuation) -> NIOInterpreter {
        return NIOInterpreter { env in
            return cont
        }
    }

    static func redirect(path: String, headers: [String: String] = [:]) -> NIOInterpreter {
        return NIOInterpreter { env in
            // We're using seeOther (303) because it won't do a POST but always a GET (important for forms)
            var head = HTTPResponseHead(version: env.header.version, status: .seeOther)
            head.headers.add(name: "Location", value: path)
            for (key, value) in headers {
                head.headers.add(name: key, value: value)
            }
            let part = HTTPServerResponsePart.head(head)
            _ = env.ctx.channel.write(part)
            _ = env.ctx.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).then {
                env.ctx.channel.close()
            }
            return nil
        }
    }
    
    static func writeFile(path: String, maxAge: UInt64? = 60) -> NIOInterpreter {
        return NIOInterpreter { deps in
            let fullPath = deps.resourcePaths.resolve(path) ?? URL(fileURLWithPath: "")
            let fileHandleAndRegion = deps.fileIO.openFile(path: fullPath.path, eventLoop: deps.ctx.eventLoop)
            fileHandleAndRegion.whenFailure { _ in
                _ = write("Error", status: .badRequest).run(deps)
            }
            fileHandleAndRegion.whenSuccess { (file, region) in
                var response = HTTPResponseHead(version: deps.header.version, status: .ok)
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
                deps.ctx.write(deps.handler.wrapOutboundOut(.head(response)), promise: nil)
                deps.ctx.writeAndFlush(deps.handler.wrapOutboundOut(.body(.fileRegion(region)))).then {
                    let p: EventLoopPromise<Void> = deps.ctx.eventLoop.newPromise()
                    deps.ctx.writeAndFlush(deps.handler.wrapOutboundOut(.end(nil)), promise: p)
                    
                    return p.futureResult
                    }.thenIfError { (_: Error) in
                        deps.ctx.close()
                    }.whenComplete {
                        _ = try? file.close()
                }
            }
            return nil
        }
    }
    
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> NIOInterpreter) -> NIOInterpreter {
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
    
    static func write(_ data: Data, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> NIOInterpreter {
        return NIOInterpreter { env in
            var head = HTTPResponseHead(version: env.header.version, status: status)
            for (key, value) in headers {
                head.headers.add(name: key, value: value)
            }
            let part = HTTPServerResponsePart.head(head)
            _ = env.ctx.channel.write(part)
            var buffer = env.ctx.channel.allocator.buffer(capacity: data.count)
            buffer.write(bytes: data)
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = env.ctx.channel.write(bodyPart)
            _ = env.ctx.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).then {
                env.ctx.channel.close()
            }
            return nil
        }
    }

    static func write(_ string: String, status: HTTPResponseStatus = .ok, headers: [String: String] = [:]) -> NIOInterpreter {
        return NIOInterpreter { env in
            var head = HTTPResponseHead(version: env.header.version, status: status)
            for (key, value) in headers {
                head.headers.add(name: key, value: value)
            }
            let part = HTTPServerResponsePart.head(head)
            _ = env.ctx.channel.write(part)
            var buffer = env.ctx.channel.allocator.buffer(capacity: string.utf8.count)
            buffer.write(string: string)
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = env.ctx.channel.write(bodyPart)
            _ = env.ctx.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).then {
                env.ctx.channel.close()
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
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        switch reqPart {
        case .head(let header):
            accumData = Data()
            
            let cookies = header.headers["Cookie"].first.map {
                $0.split(separator: ";").compactMap { $0.trimmingCharacters(in: .whitespaces).keyAndValue }
            } ?? []
            let env = NIOInterpreter.Deps(header: header, ctx: ctx, fileIO: fileIO, handler: self, manager: FileManager.default, resourcePaths: paths)

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
                let env = NIOInterpreter.Deps(header: header, ctx: ctx, fileIO: fileIO, handler: self, manager: FileManager.default, resourcePaths: paths)
                let result = p(accumData).run(env)
                accumData = Data()
                assert(result == nil, "Can't read post data twice")
            }
        }
    }
}



struct Server {
    let threadPool: BlockingIOThreadPool = {
        let t = BlockingIOThreadPool(numberOfThreads: 1)
        t.start()
        return t
    }()
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private let fileIO: NonBlockingFileIO
    private let handle: (Request) -> NIOInterpreter?
    private let paths: [URL]

    init(handle: @escaping (Request) -> NIOInterpreter?, resourcePaths: [URL]) {
        fileIO = NonBlockingFileIO(threadPool: threadPool)
        self.handle = handle
        paths = resourcePaths
    }
    
    func execute(_ f: @escaping () -> ()) {
        group.next().execute(f)
    }
    
    func listen(port: Int = 8765) throws {
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
