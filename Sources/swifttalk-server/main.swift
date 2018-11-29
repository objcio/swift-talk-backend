import Foundation
import NIO
import NIOHTTP1
import PostgreSQL


struct NoDatabaseConnection: Error { }

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

try runMigrations()
refreshStaticData()

let queue = DispatchQueue(label: "com.domain.app.timer")
let timer = DispatchSource.makeTimerSource(queue: queue)
timer.schedule(deadline: .now(), repeating: 10.0, leeway: .seconds(1))
timer.setEventHandler {
    tryOrLog {
        let conn = lazyConnection()
        func process(_ tasks: ArraySlice<Row<TaskData>>) {
            guard let task = tasks.first else { return }
            try? task.process(conn) { _ in
                process(tasks.dropFirst())
            }
        }
        let tasks = try conn.get().execute(Row<TaskData>.dueTasks)
        process(tasks[...])
    }
}
timer.resume()

let server = Server(handle: { request in
    guard let route = Route(request) else { return nil }
    let sessionString = request.cookies.first { $0.0 == "sessionid" }?.1
    let sessionId = sessionString.flatMap { UUID(uuidString: $0) }
    let conn = lazyConnection()
    return catchAndDisplayError {
        return try route.interpret(sessionId: sessionId, connection: conn)
    }
}, resourcePaths: resourcePaths)
try server.listen(port: env.port ?? 8765)
