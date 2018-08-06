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

enum MyRoute: Equatable {
    case home
    case books
    case issues
    case env
    case episodes
    case version
    case sitemap
    case collections
    case collection(String)
    case episode(Slug<Episode>)
    case staticFile(path: [String])
}

struct Slug<A>: Equatable {
    let name: String
    init(_ name: String) { self.name = name }
}

let episode: Route<MyRoute> = (Route<()>.c("episodes") / .string()).transform({ MyRoute.episode(Slug($0)) }, { r in
    guard case let .episode(num) = r else { return nil }
    return num.name
})

let collection: Route<MyRoute> = (Route<()>.c("collections") / .string()).transform({ MyRoute.collection($0) }, { r in
    guard case let .collection(name) = r else { return nil }
    return name
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
    .c("collections", .collections),
    episode,
    collection
].choice()

func inWhitelist(_ path: [String]) -> Bool {
    return !path.contains("..")
}

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

let fm = FileManager.default
extension Array where Element == URL {
    func resolve(_ path: String) -> URL? {
        return lazy.map { $0.appendingPathComponent(path) }.filter { fm.fileExists(atPath: $0.path) }.first
    }
}

extension Node {
    static func link(to: MyRoute, _ children: ToElements, attributes: [String:String] = [:]) -> Node {
        return Node.a(attributes: attributes, children, href: routes.print(to)!.prettyPath)
    }
    
    static func inlineSvg(path: String, attributes: [String:String] = [:]) -> Node {
        let name = resourcePaths.resolve("images/" + path)!
        let contents = try! String(contentsOf: name).replacingOccurrences(of: "<svg", with: "<svg " + attributes.asAttributes) // todo proper xml parsing?
        return .raw(contents)
    }
}


let allEpisodes: [Episode] = {
    // for this (and the rest of the app) to work we need to launch with a correct working directory (root of the app)
    let d = try! Data(contentsOf: URL(fileURLWithPath: "data/episodes.json"))
    let e = try! JSONDecoder().decode([Episode].self, from: d)
    return e
}()


extension MyRoute {
    func interpret<I: Interpreter>() -> I {
        switch self {
        case .books, .issues:
            return .notFound()
        case .collections:
            return .write("TODO")
        case .collection(let name):
            return .write("TODO collection")
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
            let header = pageHeader(HeaderContent.other(header: "Swift Talk", blurb: "A weekly video series on Swift programming."))
            let body: Node = .section(attributes: ["class": "container"], [
                Node.header(attributes: ["class": "mb+"], [
            		.h2("Recent Episodes", attributes: ["class": "inline-block bold color-black"]),
            		.link(to: .episodes, "See All", attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-under"])
                ]),
            .div(class: "m-cols flex flex-wrap", [
                .div(class: "mb++ p-col width-full l+|width-1/2", [
                    allEpisodes.first!.render(Episode.ViewOptions(featured: true))
                ]),
                .div(class: "p-col width-full l+|width-1/2", [
            		.div(class: "s+|cols s+|cols--2n",
                         allEpisodes[1..<5].map { ep in
                            .div(class: "mb++ s+|col s+|width-1/2", [ep.render(Episode.ViewOptions())])
                        }
            		)
                ])
                ])
            ])
            return .write(LayoutConfig(contents: [header, body]).layout, status: .ok)
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

print("Hello")
print(siteMap(routes))
let s = MyServer(parse: { routes.runParse($0) }, interpret: { $0.interpret() }, resourcePaths: resourcePaths)
print("World")
try s.listen()
