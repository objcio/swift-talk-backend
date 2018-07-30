import Foundation
import NIO
import NIOHTTP1
import PostgreSQL

// Inspired/parts copied from http://www.alwaysrightinstitute.com/microexpress-nio/

let env = ProcessInfo.processInfo.environment

let postgreSQL = try? PostgreSQL.Database(connInfo: ConnInfo.params([
    "host": env["RDS_HOSTNAME"] ?? "localhost",
    "dbname": env["RDS_DB_NAME"] ?? "swifttalk",
    "user": env["RDS_DB_USERNAME"] ?? "chris",
    "password": env["RDS_DB_PASSWORD"] ?? ""
]))

func withConnection<A>(_ x: (Connection?) -> A) -> A {
    let conn: Connection? = postgreSQL.flatMap { try? $0.makeConnection() }
    let result = x(conn)
    try? conn?.close()
    return result
}


enum Route {
    case home
    case env
    case episodes
    case version
    case sitemap
    case episode(String)
    case staticFile(path: [String])
}

let episode: Endpoint<Route> = (.c("episodes") / .string()).transform(Route.episode, { r in
    guard case let .episode(num) = r else { fatalError() }
    return num
})

let routes: Routes<Route> = [
    Endpoint(.home),
    .c("env", .env),
    .c("version", .version),
    .c("episodes", .episodes),
    .c("sitemap", .sitemap),
    (.c("static") / .path()).transform({ Route.staticFile(path:$0) }, { r in
        guard case let .staticFile(path) = r else { fatalError() }
        return path
    }),
    episode
]

func parse<A>(_ request: Request, route: Routes<A>) -> A? {
    for r in route {
        if let p = r.runParse(request) { return p }
    }
    return nil
}

protocol Interpreter {
    static func write(_ string: String, status: HTTPResponseStatus) -> Self
    static func writeFile(path: String) -> Self
}

extension Interpreter {
    static func write(_ string: String) -> Self {
        return .write(string, status: .ok)
    }
}

func inWhitelist(_ path: [String]) -> Bool {
    return path == ["assets", "stylesheets", "application.css"]
}

extension Route {
    func interpret<I: Interpreter>() -> I {
        switch self {
        case .env:
            return .write("\(ProcessInfo.processInfo.environment)")
        case .version:
            return .write(withConnection { conn in
                let v = try? conn?.execute("SELECT version()") ?? nil
                return v.map { "\($0)" } ?? "no version"
            })
        case .episode(let s):
            return .write("Episode \(s)")
        case .episodes:
            return .write("All episodes")
        case .home:
            return .write("home")
        case .sitemap:
            return .write(siteMap(routes))
        case let .staticFile(path: p):
            guard inWhitelist(p) else {
                return .write("forbidden", status: .forbidden)
            }
            return .writeFile(path: p.joined(separator: "/"))
        }
    }
}

func siteMap<A>(_ routes: Routes<A>) -> String {
    return routes.map { $0.description.pretty }.joined(separator: "\n")
}

extension HTTPMethod {
    init(_ value: NIOHTTP1.HTTPMethod) {
        switch value {
        case .GET: self = .get
        case .POST: self = .post
        default: fatalError() // todo
        }
    }
}

struct NIOInterpreter: Interpreter {
    struct Deps {
        let header: HTTPRequestHead
        let ctx: ChannelHandlerContext
        let fileIO: NonBlockingFileIO
        let handler: HelloHandler
        let baseURL: URL
    }
    let run: (Deps) -> ()
    
    static func writeFile(path: String) -> NIOInterpreter {
        return NIOInterpreter { deps in
            // todo we should check the path for things like ".."
            let fullPath = deps.baseURL.appendingPathComponent(path)
            let fileHandleAndRegion = deps.fileIO.openFile(path: fullPath.path, eventLoop: deps.ctx.eventLoop)
            print(fullPath)
            fileHandleAndRegion.whenFailure { _ in
                write("Error", status: .badRequest).run(deps)
            }
            fileHandleAndRegion.whenSuccess { (file, region) in
                var response = HTTPResponseHead(version: deps.header.version, status: .ok)
                response.headers.add(name: "Content-Length", value: "\(region.endIndex)")
                response.headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
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

final class HelloHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    
    let fileIO: NonBlockingFileIO
    init(_ fileIO: NonBlockingFileIO) {
        self.fileIO = fileIO
    }
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        switch reqPart {
        case .head(let header):
            let r = Request(path: header.uri.split(separator: "/").map(String.init), query: [:], method: .init(header.method), body: nil)
            let env = NIOInterpreter.Deps(header: header, ctx: ctx, fileIO: fileIO, handler: self, baseURL: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
            if let route = parse(r, route: routes) {
                let i: NIOInterpreter = route.interpret()
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

let threadPool = BlockingIOThreadPool(numberOfThreads: 6)
threadPool.start()
let fileIO = NonBlockingFileIO(threadPool: threadPool)


struct MyServer {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)

    func listen(port: Int = 8765) throws {
        let reuseAddr = ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET),
                                              SO_REUSEADDR)
        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(reuseAddr, value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).then {
                    channel.pipeline.add(handler: HelloHandler(fileIO))
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

print("Hello")
let s = MyServer()
print("World")
try s.listen()
