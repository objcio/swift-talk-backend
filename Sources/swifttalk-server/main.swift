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
}

let episode: SingleRoute<Route> = (.c("episodes") / .string()).transform({ Route.episode($0)}, { r in
    guard case let .episode(num) = r else { fatalError() }
    return num
})

let routes: Routes<Route> = [
    SingleRoute(.home),
    .c("env", .env),
    .c("version", .version),
    .c("episodes", .episodes),
    .c("sitemap", .sitemap),
    episode
]

func parse<A>(_ request: Request, route: Routes<A>) -> A? {
    for r in route {
        if let p = r.runParse(request) { return p }
    }
    return nil
}

func sitemap<A>(_ routes: Routes<A>) -> String {
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

final class HelloHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        switch reqPart {
        case .head(let header):
            let head = HTTPResponseHead(version: header.version, status: .ok)
            let part = HTTPServerResponsePart.head(head)
            _ = ctx.channel.write(part)
            
            let r = Request(path: header.uri.split(separator: "/").map(String.init), query: [:], method: .init(header.method), body: nil)
            let responseStr: String
            if let route = parse(r, route: routes) {
                switch route {
                case .env:
                    responseStr = "\(ProcessInfo.processInfo.environment)"
                case .version:
                    responseStr = withConnection { conn in
                        let v = try? conn?.execute("SELECT version()") ?? nil
                        return v.map { "\($0)" } ?? "no version"
                    }
                case .episode(let s):
                    responseStr = "Episode \(s)"
                case .episodes:
                    responseStr = "All episodes"
                case .home:
                    responseStr = "home"
                case .sitemap:
                    responseStr = sitemap(routes)
                }
            } else {
                responseStr = "not found"
            }
            

            var buffer = ctx.channel.allocator.buffer(capacity: responseStr.utf8.count)
            buffer.write(string: responseStr)
            let bodyPart = HTTPServerResponsePart.body(.byteBuffer(buffer))
            _ = ctx.channel.write(bodyPart)
            _ = ctx.channel.writeAndFlush(HTTPServerResponsePart.end(nil)).then {
                ctx.channel.close()
            }
        case .body, .end:
            break
        }
    }
}

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
                    channel.pipeline.add(handler: HelloHandler())
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
