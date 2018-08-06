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
    case imprint
    case subscribe
    case collections
    case collection(Slug<Collection>)
    case episode(Slug<Episode>)
    case staticFile(path: [String])
}

let episode: Route<MyRoute> = (Route<()>.c("episodes") / .string()).transform({ MyRoute.episode(Slug(rawValue: $0)) }, { r in
    guard case let .episode(num) = r else { return nil }
    return num.rawValue
})

let collection: Route<MyRoute> = (Route<()>.c("collections") / .string()).transform({ MyRoute.collection(Slug(rawValue: $0)) }, { r in
    guard case let .collection(name) = r else { return nil }
    return name.rawValue
})

let routes: Route<MyRoute> = [
    Route(.home),
    .c("env", .env),
    .c("version", .version),
    .c("books", .books), // todo absolute url
    .c("issues", .issues), // todo absolute url
    .c("episodes", .episodes),
    .c("sitemap", .sitemap),
    .c("subscribe", .subscribe),
    .c("imprint", .imprint),
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

import CommonMark

extension Node {
    static func link(to: MyRoute, _ children: ToElements, attributes: [String:String] = [:]) -> Node {
        return Node.a(attributes: attributes, children, href: routes.print(to)!.prettyPath)
    }
    
    static func inlineSvg(path: String, attributes: [String:String] = [:]) -> Node {
        let name = resourcePaths.resolve("images/" + path)!
        let contents = try! String(contentsOf: name).replacingOccurrences(of: "<svg", with: "<svg " + attributes.asAttributes) // todo proper xml parsing?
        return .raw(contents)
    }
    
    static func markdown(_ string: String) -> Node {
        return Node.raw(CommonMark.Node(markdown: string)!.html)
    }
}

extension Scanner {
    var remainder: String {
        return NSString(string: string).substring(from: scanLocation)
    }
}

extension String {
    func scanTimePrefix() -> (minutes: Int, seconds: Int, remainder: String)? {
        let s = Scanner(string: self)
        var minutes: Int = 0
        var seconds: Int = 0
        if s.scanInt(&minutes), s.scanString(":", into: nil), s.scanInt(&seconds) {
            return (minutes, seconds, s.remainder)
        } else {
            return nil
        }
    }
}

func absoluteURL(_ route: MyRoute) -> URL? {
    guard let p = routes.print(route)?.prettyPath else { return nil }
    return URL(string: "https://www.objc.io" + p)
}

extension Episode {
    var rawTranscript: String? {
        let path = URL(fileURLWithPath: "data/episode-transcripts/episode\(number).md")
        return try? String(contentsOf: path)
    }
    
    var transcript: CommonMark.Node? {
        guard let t = rawTranscript, let nodes = CommonMark.Node(markdown: t) else { return nil }
        return CommonMark.Node(blocks: nodes.elements.deepApply({ (inl: Inline) -> [Inline] in
            guard case let .text(t) = inl else { return [inl] }
            if let (m,s,remainder) = t.scanTimePrefix() {
                let totalSeconds = m*60 + s
                let pretty = "\(m.padded):\(s.padded)"
                return [Inline.link(children: [.text(text: pretty)], title: "", url: "#\(totalSeconds)"), .text(text: remainder)]
            } else {
                return [inl]
            }
        }))
    }

    var tableOfContents: [((TimeInterval), title: String)] {
        guard let t = rawTranscript, let els = CommonMark.Node(markdown: t)?.elements else { return [] }
        
        var result: [(TimeInterval, title: String)] = []
        var currentTitle: String?
        for el in els {
            switch el {
            case let .heading(text: text, _):
                let strs = text.deep(collect: { (i: Inline) -> [String] in
                    guard case let Inline.text(text: t) = i else { return [] }
                    return [t]
                })
                currentTitle = strs.joined(separator: " ")
            case let .paragraph(text: c) where currentTitle != nil:
                if case let .text(t)? = c.first, let (minutes, seconds, _) = t.scanTimePrefix() {
                    result.append((TimeInterval(minutes*60 + seconds), title: currentTitle!))
                    currentTitle = nil
                }
            default:
                ()
            }
        }
        return result
    }

    static let all: [Episode] = {
        // for this (and the rest of the app) to work we need to launch with a correct working directory (root of the app)
        let d = try! Data(contentsOf: URL(fileURLWithPath: "data/episodes.json"))
        let e = try! JSONDecoder().decode([Episode].self, from: d)
        return e

    }()
    
}

extension Collection {
    static let all: [Collection] = {
        // for this (and the rest of the app) to work we need to launch with a correct working directory (root of the app)
        let d = try! Data(contentsOf: URL(fileURLWithPath: "data/collections.json"))
        let e = try! JSONDecoder().decode([Collection].self, from: d)
        return e
        
    }()
}


extension MyRoute {
    func interpret<I: Interpreter>() -> I {
        switch self {
        case .books, .issues:
            return .notFound()
        case .collections, .imprint, .subscribe:
            return .write("TODO")
        case .collection(let name):
            guard let c = Collection.all.first(where: { $0.slug == name }) else {
                return I.notFound("No such collection")
            }
            return .write("TODO collection: \(c)")
        case .env:
            return .write("\(ProcessInfo.processInfo.environment)")
        case .version:
            return .write(withConnection { conn in
                let v = try? conn?.execute("SELECT version()") ?? nil
                return v.map { "\($0)" } ?? "no version"
            })
        case .episode(let s):
            guard let ep = Episode.all.first(where: { $0.slug == s}) else {
                return .notFound("No such episode")
            }            
            return .write(ep.show())
        case .episodes:
            return .write("All episodes")
        case .home:
            return .write(LayoutConfig(contents: renderHome()).layout, status: .ok)
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
