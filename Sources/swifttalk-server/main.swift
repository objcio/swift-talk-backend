import Foundation
import NIO
import NIOHTTP1
import PostgreSQL


var standardError = FileHandle.standardError

extension Foundation.FileHandle : TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

func readDotEnv() -> [String:String] {
    guard let c = try? String(contentsOfFile: ".env") else { return [:] }
    return Dictionary(c.split(separator: "\n").compactMap { $0.keyAndValue }, uniquingKeysWith: { $1 })
}

struct Env {
    let env: [String:String] = readDotEnv().merging(ProcessInfo.processInfo.environment, uniquingKeysWith: { $1 })

    subscript(optional string: String) -> String? {
        return env[string]
    }
    
    subscript(string: String) -> String {
        guard let e = env[string] else {
            print("Forgot to set env variable \(string)", to: &standardError)
            return ""
        }
        return e
    }
    
    init() {
        // todo a different check than assert (gets compiled out during release)
        assert(env["GITHUB_CLIENT_ID"] != nil)
        assert(env["GITHUB_CLIENT_SECRET"] != nil)
    }
}

let env = Env()



let postgreSQL = try? PostgreSQL.Database(connInfo: ConnInfo.params([
    "host": env[optional: "RDS_HOSTNAME"] ?? "localhost",
    "dbname": env[optional: "RDS_DB_NAME"] ?? "swifttalk_dev",
    "user": env[optional: "RDS_DB_USERNAME"] ?? "chris",
    "password": env[optional: "RDS_DB_PASSWORD"] ?? "",
    "connect_timeout": "1",
]))

func withConnection<A>(_ x: (Connection?) throws -> A) rethrows -> A {
    let conn: Connection? = postgreSQL.flatMap {
        do {
            let conn = try $0.makeConnection()
            return conn
        } catch {
            print(error, to: &standardError)
//            print(env.filter({ $0.0.hasPrefix("RDS" )}))
            print(error.localizedDescription, to: &standardError)
            return nil
        }
    }
    let result = try x(conn)
    try? conn?.close()
    return result
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
    static func link(to: MyRoute, _ children: [Node], attributes: [String:String] = [:]) -> Node {
        return Node.a(attributes: attributes, children, href: routes.print(to)!.prettyPath)
    }
    
    static func inlineSvg(path: String, preserveAspectRatio: String? = nil, attributes: [String:String] = [:]) -> Node {
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


extension MyRoute {
    func interpret<I: Interpreter>() -> I {
        switch self {
        case .books, .issues:
            return .notFound()
        case .collections:
            return I.write(index(Collection.all))
        case .imprint, .subscribe:
            return .write("TODO")
        case .collection(let name):
            guard let c = Collection.all.first(where: { $0.slug == name }) else {
                return I.notFound("No such collection")
            }
            return .write(c.show())
        case .login:
            return I.redirect(path: "https://github.com/login/oauth/authorize?scope=user:email&client_id=\(Github.clientId)")
        case .githubCallback(let code):
            return I.onComplete(promise:
                URLSession.shared.load(Github.getAccessToken(code)).map({ $0?.access_token })
            	, do: { token in
                guard let t = token else { return .write("No access") }
                return I.onComplete(promise: URLSession.shared.load(Github(t).profile), do: { str in
                    guard let p = str else { return .write("No profile") }
                    do {
                        return try withConnection { conn in
                            print("conn: \(conn)", to: &standardError)
                            guard let c = conn else { return .write("No database connection") }
                            let d = Database(c)
                            // todo ask for email if we don't get it
                            let uid = try d.insert(UserData(email: p.email ?? "no email", githubUID: p.id, githubLogin: p.login, githubToken: t, avatarURL: p.avatar_url, name: p.name ?? ""))
                            print("got uid: \(uid)", to: &standardError)
                            return .write("Hello \(uid)")
                        }
                    } catch {
                        print("something else: \(error)", to: &standardError)
                        print("something else: \(error.localizedDescription)", to: &standardError)
                        return I.write("Error", status: .internalServerError)
                    }
                })
                
            })
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
            return I.write(index(Episode.all.filter { $0.released }))
        case .home:
            return .write(LayoutConfig(contents: renderHome()).layout, status: .ok)
        case .sitemap:
            return .write(siteMap(routes))
        case let .staticFile(path: p):
            guard inWhitelist(p) else {
                return .write("forbidden", status: .forbidden)
            }
            let name = p.map { $0.removingPercentEncoding ?? "" }.joined(separator: "/")
            return .writeFile(path: name)
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

func sanityCheck() {
    for e in Episode.all {
        for c in e.collections {
            assert(Collection.all.contains(where: { $0.title == c }))
        }
    }
}

do {
    try withConnection { conn in
        guard let c = conn else {
            print("Can't connect to database")
            return
        }
        let db = Database(c)
        try db.migrate()
    //    try db.createUser("chris", 123)
    }
} catch {
    print("Migration error: \(error, error.localizedDescription)", to: &standardError)
}

//print(siteMap(routes))
sanityCheck()
let s = MyServer(parse: { routes.runParse($0) }, interpret: { $0.interpret() }, resourcePaths: resourcePaths)
try s.listen()


