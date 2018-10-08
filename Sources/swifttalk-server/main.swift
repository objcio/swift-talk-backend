import Foundation
import NIO
import NIOHTTP1
import PostgreSQL


var standardError = FileHandle.standardError
let env = Env()

let recurly = Recurly(subdomain: "\(env["RECURLY_SUBDOMAIN"]).recurly.com", apiKey: env["RECURLY_API_KEY"])



func log(_ e: Error) {
    print(e.localizedDescription, to: &standardError)
}

func log(error: String) {
    print(error, to: &standardError)
}

struct NoDatabaseConnection: Error { }

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

runMigrations()
verifyStaticData()

let s = MyServer(handle: { request in
    guard let route = Route(request) else { return nil }
    let sessionString = request.cookies.first { $0.0 == "sessionid" }?.1
    let sessionId = sessionString.flatMap { UUID(uuidString: $0) }
    let conn = Lazy<Connection>({ () throws -> Connection in
        let c: Connection? = postgreSQL.flatMap {
            do {
                let conn = try $0.makeConnection()
                return conn
            } catch {
                print(error, to: &standardError)
                print(error.localizedDescription, to: &standardError)
                return nil
            }
        }
        if let conn = c {
            return conn
        } else {
            throw NoDatabaseConnection()
        }
    }, cleanup: { conn in
        try? conn.close()
    })
    return catchAndDisplayError {
        return try route.interpret(sessionId: sessionId, connection: conn)
    }
}, resourcePaths: resourcePaths)
try s.listen()


