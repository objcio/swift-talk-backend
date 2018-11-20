import Foundation
import NIO
import NIOHTTP1
import PostgreSQL


struct NoDatabaseConnection: Error { }

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

try runMigrations()
DispatchQueue.global().async { verifyStaticData() }

let s = MyServer(handle: { request in
    guard let route = Route(request) else { return nil }
    let sessionString = request.cookies.first { $0.0 == "sessionid" }?.1
    let sessionId = sessionString.flatMap { UUID(uuidString: $0) }
    let conn = lazyConnection()
    return catchAndDisplayError {
        return try route.interpret(sessionId: sessionId, connection: conn)
    }
}, resourcePaths: resourcePaths)
try s.listen(port: env.port ?? 8765)


