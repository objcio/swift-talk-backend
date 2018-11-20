//
//  Server.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat


enum HTTPMethod: String, Codable {
    case post = "POST"
    case get = "GET"
}

struct Request {
    var path: [String]
    var query: [String:String]
    var method: HTTPMethod
    var cookies: [(String, String)]
}

protocol Interpreter {
    static func write(_ string: String, status: HTTPResponseStatus, headers: [String: String]) -> Self
    static func writeFile(path: String) -> Self
    static func redirect(path: String, headers: [String: String]) -> Self
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> Self) -> Self
    static func withPostData(do cont: @escaping (Data) -> Self) -> Self
}

struct Promise<A> {
    public let run: (@escaping (A) -> ()) -> ()
    init(_ run: @escaping ((@escaping (A) -> ()) -> ())) {
        self.run = run
    }
    
    func map<B>(_ f: @escaping (A) -> B) -> Promise<B> {
        return Promise<B> { cb in
            self.run { a in
                cb(f(a))
            }
        }
    }
    
    func flatMap<B>(_ f: @escaping (A) -> Promise<B>) -> Promise<B> {
        return Promise<B> { cb in
            self.run { a in
                let p = f(a)
                p.run(cb)
            }
        }
    }
}

func sequentially<A>(_ promises: [Promise<A>]) -> Promise<[A]> {
    let initial: Promise<[A]> = Promise { $0([]) }
    return promises.reduce(initial) { result, promise in
        return result.flatMap { (existing: [A]) in
            promise.map { new in
                return existing + [new]
            }
        }
    }
}

extension Interpreter {
    static func notFound(_ string: String = "Not found") -> Self {
        return .write(string, status: .notFound)
    }

    static func write(_ string: String, status: HTTPResponseStatus = .ok) -> Self {
        return .write(string, status: status, headers: [:])
    }

    static func write(_ html: Node, status: HTTPResponseStatus = .ok) -> Self {
        return .write(html.htmlDocument)
    }
    
    static func redirect(path: String) -> Self {
        return .redirect(path: path, headers: [:])
    }
    
    static func redirect(to route: Route, headers: [String: String] = [:]) -> Self {
        return .redirect(path: route.path, headers: headers)
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) -> Self) -> Self {
        return .withPostData { data in
            let result = String(data: data, encoding: .utf8)?.parseAsQueryPart
            return cont(result ?? [:])
        }
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) -> Self, or: @escaping () -> Self) -> Self {
        return .withPostData { data in
            let result = String(data: data, encoding: .utf8)?.parseAsQueryPart
            if let r = result {
                return cont(r)
            } else {
                return or()
            }
        }
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
    
    static func writeFile(path: String) -> NIOInterpreter {
        return NIOInterpreter { deps in
            // todo we should check the path for things like ".."
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

extension StringProtocol {
    var keyAndValue: (String, String)? {
        guard let i = index(of: "=") else { return nil }
        let n = index(after: i)
        return (String(self[..<i]), String(self[n...]).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
    }
}

extension String {
    fileprivate var decoded: String {
    	return (removingPercentEncoding ?? "").replacingOccurrences(of: "+", with: " ")
    }
}

extension StringProtocol {
    var parseAsQueryPart: [String:String] {
        let items = split(separator: "&").compactMap { $0.keyAndValue }
        return Dictionary(items.map { (k,v) in (k.decoded, v.decoded) }, uniquingKeysWith: { $1 })
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

extension HTTPMethod {
    init(_ value: NIOHTTP1.HTTPMethod) {
        switch value {
        case .GET: self = .get
        case .POST: self = .post
        default: fatalError("Unsupported method: \(value)") // todo
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
            let (path, query) = header.uri.parseQuery
            let cookies = header.headers["Cookie"].first.map {
                $0.split(separator: ";").compactMap { $0.trimmingCharacters(in: .whitespaces).keyAndValue }
            } ?? []
            let r = Request(path: path.split(separator: "/").map(String.init), query: query, method: .init(header.method), cookies: cookies)
            let env = NIOInterpreter.Deps(header: header, ctx: ctx, fileIO: fileIO, handler: self, manager: FileManager.default, resourcePaths: paths)
            if let i = handle(r) {
                if let c = i.run(env) {
                    postCont = (c, header)
                }
            } else {
                print("Not found: \(header.uri)")
                _ = NIOInterpreter.write("Not found: \(header.uri)").run(env)
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



struct MyServer {
    let threadPool: BlockingIOThreadPool = {
        let t = BlockingIOThreadPool(numberOfThreads: 1)
        t.start()
        return t
    }()
    let fileIO: NonBlockingFileIO
    let handle: (Request) -> NIOInterpreter?
    let paths: [URL]
    init(handle: @escaping (Request) -> NIOInterpreter?, resourcePaths: [URL]) {
        fileIO = NonBlockingFileIO(threadPool: threadPool)
        self.handle = handle
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
