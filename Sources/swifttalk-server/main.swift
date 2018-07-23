import Foundation
import NIO
import NIOHTTP1
import PostgreSQL

// Inspired/parts copied from http://www.alwaysrightinstitute.com/microexpress-nio/

let env = ProcessInfo.processInfo.environment

let postgreSQL = try PostgreSQL.Database(connInfo: ConnInfo.params([
    "host": env["RDS_HOSTNAME"] ?? "localhost",
    "dbname": env["RDS_DB_NAME"] ?? "postgres",
    "user": env["RDS_DB_USERNAME"] ?? "chris",
    "password": env["RDS_DB_PASSWORD"] ?? ""
]))
let conn = try postgreSQL.makeConnection()

let version = try conn.execute("SELECT version()")
print(version)

final class HelloHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    
    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        switch reqPart {
        case .head(let header):
            let head = HTTPResponseHead(version: header.version, status: .ok)
            let part = HTTPServerResponsePart.head(head)
            _ = ctx.channel.write(part)
            
            let responseStr: String
            if header.uri == "/env" {
                responseStr = "\(ProcessInfo.processInfo.environment)"
            } else if header.uri == "/version" {
                let v = try? conn.execute("SELECT version()")
                responseStr = v.map { "\($0)" } ?? "no version"
            } else {
                responseStr = "Hello, world + \(header)"
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
