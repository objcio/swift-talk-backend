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

extension Endpoint where A == Route {
    static let home: Endpoint<Route> = Endpoint(Route.home)
}

let routes: Routes<Route> = [
    .home,
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

func inWhitelist(_ path: [String]) -> Bool {
    return path == ["assets", "stylesheets", "application.css"]
}

extension Node {
    func link(to: Endpoint<Route>, children: [Node]) {
        return Node.a(title: children, href: to.print)
    }
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

let episodes: [Episode] = {
    // for this (and the rest of the app) to work we need a correct working directory (root of the app)
    let d = try! Data(contentsOf: URL(fileURLWithPath: "data/episodes.json"))
    let e = try! JSONDecoder().decode([Episode].self, from: d)
    return e
}()
print("Hello")

let s = MyServer(parse: { parse($0, route: routes) }, interpret: { $0.interpret() })
print("World")
try s.listen()
