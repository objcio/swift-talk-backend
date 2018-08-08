//
//  Server.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation
import NIO
import NIOHTTP1

protocol Interpreter {
    static func write(_ string: String, status: HTTPResponseStatus) -> Self
    static func writeFile(path: String) -> Self
    static func redirect(path: String) -> Self
}

extension Interpreter {
    static func notFound(_ string: String = "Not found") -> Self {
        return .write(string, status: .notFound)
    }
    static func write(_ string: String) -> Self {
        return .write(string, status: .ok)
    }
    
    static func write(_ html: Node, status: HTTPResponseStatus = .ok) -> Self {
        return .write(html.document)
    }
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
    let run: (Deps) -> ()
    
    static func redirect(path: String) -> NIOInterpreter {
        return NIOInterpreter { env in
            var head = HTTPResponseHead(version: env.header.version, status: .temporaryRedirect) // todo should this be temporary?
            head.headers.add(name: "Location", value: path)
            let part = HTTPServerResponsePart.head(head)
            _ = env.ctx.channel.write(part)
            _ = env.ctx.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).then {
                env.ctx.channel.close()
            }
        }
    }
    
    static func writeFile(path: String) -> NIOInterpreter {
        return NIOInterpreter { deps in
            // todo we should check the path for things like ".."
            let fullPath = deps.resourcePaths.resolve(path) ?? URL(fileURLWithPath: "")
            
            let fileHandleAndRegion = deps.fileIO.openFile(path: fullPath.path, eventLoop: deps.ctx.eventLoop)
            fileHandleAndRegion.whenFailure { _ in
                write("Error", status: .badRequest).run(deps)
            }
            fileHandleAndRegion.whenSuccess { (file, region) in
                var response = HTTPResponseHead(version: deps.header.version, status: .ok)
                response.headers.add(name: "Content-Length", value: "\(region.endIndex)")
                let contentType: String
                // (path as NSString) doesn't work on Linux... so using the initializer below.
                switch NSString(string: path).pathExtension {
                case "css": contentType = "text/css; charset=utf-8"
                default: contentType = "text/plain; charset=utf-8"
                }
                response.headers.add(name: "Content-Type", value: contentType)
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
        }
    }
    static func write(_ string: String, status: HTTPResponseStatus = .ok) -> NIOInterpreter {
        return NIOInterpreter { env in
            let head = HTTPResponseHead(version: env.header.version, status: status)
            let part = HTTPServerResponsePart.head(head)
            _ = env.ctx.channel.write(part)
            var buffer = env.ctx.channel.allocator.buffer(capacity: string.utf8.count)
            buffer.write(string: string)
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = env.ctx.channel.write(bodyPart)
            _ = env.ctx.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).then {
                env.ctx.channel.close()
            }
        }
    }
}

extension StringProtocol {
    var keyAndValue: (String, String)? {
        guard let i = index(of: "=") else { return nil }
        let n = index(after: i)
        return (String(self[..<i]), String(self[n...]))
    }
}

extension StringProtocol {
    var parseAsQueryPart: [String:String] {
        let items = split(separator: "&").compactMap { $0.keyAndValue }
        return Dictionary(items.map { (k,v) in (k.removingPercentEncoding ?? "", v.removingPercentEncoding ?? "") }, uniquingKeysWith: { $1 })
    }
}

extension String {
    var parseQuery: (String, [String:String]) {
        guard let i = self.index(of: "?") else { return (self, [:]) }
        let path = self[..<i]
        let remainder = self[index(after: i)...]
        return (String(path), remainder.parseAsQueryPart)
    }
}

final class RouteHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    let handle: (Request) -> NIOInterpreter?
    let paths: [URL]
    
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
            let (path, query) = header.uri.parseQuery
            let r = Request(path: path.split(separator: "/").map(String.init), query: query, method: .init(header.method), body: nil)
            let env = NIOInterpreter.Deps(header: header, ctx: ctx, fileIO: fileIO, handler: self, manager: FileManager.default, resourcePaths: paths)
            if let i = handle(r) {
                i.run(env)
            } else {
                print("Not found: \(header.uri)")
                NIOInterpreter.write("Not found: \(header.uri)").run(env)
            }
        case .body, .end:
            break
        }
    }
}



struct MyServer {
    let threadPool: BlockingIOThreadPool = {
        let t = BlockingIOThreadPool(numberOfThreads: 6)
        t.start()
        return t
    }()
    let fileIO: NonBlockingFileIO
    let handle: (Request) -> NIOInterpreter?
    let paths: [URL]
    init<A>(parse: @escaping (Request) -> A?, interpret: @escaping (A) -> NIOInterpreter, resourcePaths: [URL]) {
        fileIO = NonBlockingFileIO(threadPool: threadPool)
        handle = { parse($0).map(interpret) }
        paths = resourcePaths
    }
    
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    
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
        print("Going to start listening on port \(port)")
        let channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
        try channel.closeFuture.wait()
    }
}
