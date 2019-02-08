import Foundation
import NIOWrapper
import Database
import WebServer


extension NIOInterpreter: WebServer.Response {
    public typealias R = Route
    public typealias S = Session
}

public func run() throws {
    try runMigrations()
    refreshStaticData()
    let timer = scheduleTaskTimer()


    let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

    func hashedAssetName(file: String) -> String {
        guard let remainder = file.drop(prefix: "/assets/") else { return file }
        let rep = assets.fileToHash[remainder]
        return rep.map { "/assets/" + $0 } ?? file

    }

    let server = Server(handle: { request in
        guard let route = Route(request) else { return nil }
        let sessionString = request.cookies.first { $0.0 == "sessionid" }?.1
        let sessionId = sessionString.flatMap { UUID(uuidString: $0) }
        let conn = postgres.lazyConnection()
        func buildSession() -> Session? {
            guard let sId = sessionId else { return nil }
            do {
                let user = try conn.get().execute(Row<UserData>.select(sessionId: sId))
                return try user.map { u in
                    if u.data.premiumAccess || u.data.role == .teamManager {
                        return Session(sessionId: sId, user: u, teamMember: nil, teamManager: nil, gifter: nil)
                    } else {
                        let teamMember = try conn.get().execute(u.teamMember)
                        let teamManager = try teamMember.flatMap { try conn.get().execute(Row<UserData>.select($0.data.userId)) }
                        let gifter: Row<UserData>? = try conn.get().execute(u.gifter)
                        return Session(sessionId: sId, user: u, teamMember: teamMember, teamManager: teamManager, gifter: gifter)
                    }
                }
            } catch {
                return nil
            }
        }
        let deps = RequestEnvironment(route: route, hashedAssetName: hashedAssetName, buildSession: buildSession, connection: conn, resourcePaths: resourcePaths)

        let reader: Reader<STRequestEnvironment, NIOInterpreter> = try! route.interpret()
        return reader.run(deps)
    }, resourcePaths: resourcePaths)
    try server.listen(port: env.port ?? 8765)
}
