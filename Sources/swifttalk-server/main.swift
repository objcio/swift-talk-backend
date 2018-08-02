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

enum MyRoute {
    case home
    case books
    case issues
    case env
    case episodes
    case version
    case sitemap
    case episode(String)
    case staticFile(path: [String])
}

let episode: Route<MyRoute> = (Route<()>.c("episodes") / .string()).transform(MyRoute.episode, { r in
    guard case let .episode(num) = r else { return nil }
    return num
})

extension Array where Element == Route<MyRoute> {
    func choice() -> Route<MyRoute> {
        assert(!isEmpty)
        return dropFirst().reduce(self[0], { $0.or($1) })
    }
}


let routes: Route<MyRoute> = [
    Route(.home),
    .c("env", .env),
    .c("version", .version),
    .c("books", .books), // todo absolute url
    .c("issues", .issues), // todo absolute url
    .c("episodes", .episodes),
    .c("sitemap", .sitemap),
    (.c("assets") / .path()).transform({ MyRoute.staticFile(path:$0) }, { r in
        guard case let .staticFile(path) = r else { return nil }
        return path
    }),
    episode
].choice()

func inWhitelist(_ path: [String]) -> Bool {
    return !path.contains("..")
}

extension Node {
    static func link(to: MyRoute, _ children: ToElements, attributes: [String:String] = [:]) -> Node {
        return Node.a(attributes: attributes, children, href: routes.print(to)!.prettyPath)
    }
}


let fm = FileManager.default

extension MyRoute {
    func interpret<I: Interpreter>() -> I {
        switch self {
        case .books, .issues: fatalError()
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
            return I.write(LayoutConfig(contents: "Home").layout, status: .ok)
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

func siteMap<A>(_ routes: Route<A>) -> String {
    return routes.description.pretty
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
    // for this (and the rest of the app) to work we need to launch with a correct working directory (root of the app)
    let d = try! Data(contentsOf: URL(fileURLWithPath: "data/episodes.json"))
    let e = try! JSONDecoder().decode([Episode].self, from: d)
    return e
}()
print("Hello")
print(siteMap(routes))
let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]
let s = MyServer(parse: { routes.runParse($0) }, interpret: { $0.interpret() }, resourcePaths: resourcePaths)
print("World")
try s.listen()
