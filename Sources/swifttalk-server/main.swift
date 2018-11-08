import Foundation
import NIO
import NIOHTTP1
import PostgreSQL


let env = Env()

let recurly = Recurly(subdomain: "\(env["RECURLY_SUBDOMAIN"]).recurly.com", apiKey: env["RECURLY_API_KEY"])

// The vimeo access token needs to have the "private" and "files" roles enabled to fetch the download urls for private videos
let vimeo = Vimeo(apiKey: env["VIMEO_ACCESS_TOKEN"])

struct NoDatabaseConnection: Error { }

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

try runMigrations()
verifyStaticData()

let s = MyServer(handle: { request in
    guard let route = Route(request) else { return nil }
    let sessionString = request.cookies.first { $0.0 == "sessionid" }?.1
    let sessionId = sessionString.flatMap { UUID(uuidString: $0) }
    let conn = lazyConnection()
    return catchAndDisplayError {
        return try route.interpret(sessionId: sessionId, connection: conn)
    }
}, resourcePaths: resourcePaths)
try s.listen()


