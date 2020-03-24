import Foundation
import NIOWrapper
import Database
import WebServer
import Base


public func run() throws {
    try runMigrations()
    refreshStaticData()
    let timer = scheduleTaskTimer()

    let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let resourcePaths = [currentDir.appendingPathComponent(assetsPath), currentDir.appendingPathComponent("node_modules")]

    let server = Server(resourcePaths: resourcePaths) { request in
        guard let route = Route(request) else { return nil }
        let conn = postgres.lazyConnection()
        
        func buildSession() -> Session? {
            guard let sId = request.sessionId else { return nil }
            do {
                let user = try conn.get().execute(Row<UserData>.select(sessionId: sId))
                return try user.map { u in
                    if u.data.premiumAccess {
                        return Session(sessionId: sId, user: u, teamManager: nil, gifter: nil)
                    } else {
                        let teamMember = try conn.get().execute(u.teamMember)
                        let teamManager = try teamMember.flatMap { try conn.get().execute(Row<UserData>.select($0.data.userId)) }
                        let gifter: Row<UserData>? = try conn.get().execute(u.gifter)
                        return Session(sessionId: sId, user: u, teamManager: teamManager, gifter: gifter)
                    }
                }
            } catch {
                return nil
            }
        }
        
        let env = STRequestEnvironment(route: route, hashedAssetName: assets.hashedName, buildSession: buildSession, connection: conn, resourcePaths: resourcePaths)
        let reader: Reader<STRequestEnvironment, NIOInterpreter> = try! route.interpret()
        return reader.run(env)
    }
    try server.listen(port: env.port ?? 8765)
}

extension Request {
    fileprivate var sessionId: UUID? {
        let sessionString = cookies.first { $0.0 == "sessionid" }?.1
        return sessionString.flatMap { UUID(uuidString: $0) }
    }
}
