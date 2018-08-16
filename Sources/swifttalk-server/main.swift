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

// TODO: I'm not sure if it's a good idea to initialize the plans like this. We should maybe also have static data?
private(set) var plans: [Plan] = []
let recurly = Recurly(subdomain: "\(env["RECURLY_SUBDOMAIN"]).recurly.com", apiKey: env["RECURLY_API_KEY"])
URLSession.shared.load(recurly.plans, callback: { value in
    if let p = value {
        plans = p
    } else {
        print("Could not load plans", to: &standardError) // todo: fall back to old plans?
    }
})

URLSession.shared.load(recurly.listAccounts) { a in
    if let accounts = a {
        dump(accounts.filter { $0.state == .active }.map { ($0.email, $0.account_code) })
    } else {
        print("no accounts")
    }
}

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
    static func link(to: MyRoute, _ children: [Node], classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        return Node.a(classes: classes, attributes: attributes, children, href: routes.print(to)!.prettyPath)
    }
    
    static func inlineSvg(path: String, preserveAspectRatio: String? = nil, classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        let name = resourcePaths.resolve("images/" + path)!
        var a = attributes
        if let c = classes {
            a["class", default: ""] += c.classes
        }
        let contents = try! String(contentsOf: name).replacingOccurrences(of: "<svg", with: "<svg " + a.asAttributes) // todo proper xml parsing?
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

func tryOrPrint<A>(_ f: () throws -> A?) -> A? {
    do {
        return try f()
    } catch {
        print("Error: \(error) \(error.localizedDescription)", to: &standardError)
        return nil
    }
}

struct Session {
    var user: UserResult
}

extension MyRoute {
    func interpret<I: Interpreter>(sessionId: UUID?) -> I {
        let session: Session?
        if let s = sessionId {
            session = withConnection { connection in
                guard let c = connection else { return nil }
                let database = Database(c)
                let user = tryOrPrint { try database.execute(UserResult.query(withSessionId: s)) }
                return user.map { Session(user: $0) }
            }
        } else {
            session = nil
        }
        switch self {
        case .books, .issues:
            return .notFound()
        case .collections:
            return I.write(index(Collection.all, session: session))
        case .imprint:
            return .write("TODO")
        case .subscribe:
            return .write("\(plans)")
        case .collection(let name):
            guard let c = Collection.all.first(where: { $0.slug == name }) else {
                return I.notFound("No such collection")
            }
            return .write(c.show(session: session))
        case .login:
            return I.redirect(path: "https://github.com/login/oauth/authorize?scope=user:email&client_id=\(Github.clientId)")
        case .logout:
            do {
                return try withConnection { conn in
                    guard let c = conn else { return .write("No database connection") }
                    if let s = session {
                        let d = Database(c)
                        try d.execute(s.user.deleteAllSessions)
                    }
                    return I.redirect(path: routes.print(.home)!.prettyPath)
                }
            } catch {
                print(String(describing: error), to: &standardError)
                return I.write("Error", status: .internalServerError)
            }
        case .githubCallback(let code):
            return I.onComplete(promise:
                URLSession.shared.load(Github.getAccessToken(code)).map({ $0?.access_token })
            	, do: { token in
                guard let t = token else { return .write("No access") }
                return I.onComplete(promise: URLSession.shared.load(Github(t).profile), do: { str in
                    guard let p = str else { return .write("No profile") }
                    do {
                        return try withConnection { conn in
                            guard let c = conn else { return .write("No database connection") }
                            let d = Database(c)
                            // todo ask for email if we don't get it
                            let uid: UUID
                            if let user = try d.execute(UserResult.query(withGithubId: p.id)) {
                                uid = user.id
                                print("Found existing user: \(user)")
                            } else {
                                let userData = UserData(email: p.email ?? "no email", githubUID: p.id, githubLogin: p.login, githubToken: t, avatarURL: p.avatar_url, name: p.name ?? "")
                                uid = try d.execute(userData.insert)
                                print("Created new user: \(userData)")
                            }
                            let sessionData: SessionData = SessionData(userId: uid)
                            let sid = try d.execute(sessionData.insert)
                            return I.redirect(path: "/", headers: ["Set-Cookie": "sessionid=\"\(sid.uuidString)\"; HttpOnly; Path=/"]) // TODO secure, TODO return to where user came from
                        }
                    } catch {
                        print("something else: \(error)", to: &standardError)
                        print("something else: \(error.localizedDescription)", to: &standardError)
                        return I.write("Error", status: .internalServerError)
                    }
                })
                
            })
        case .version:
            return .write(withConnection { conn -> String in
                let v = try? conn?.execute("SELECT version()") ?? nil
                return v.map { "\($0)" } ?? "no version"
            })
        case .episode(let s):
            guard let ep = Episode.all.first(where: { $0.slug == s}) else {
                return .notFound("No such episode")
            }            
            return .write(ep.show(session: session))
        case .episodes:
            return I.write(index(Episode.all.filter { $0.released }, session: session))
        case .home:
            return .write(LayoutConfig(session: session, contents: renderHome(session: session)).layout, status: .ok)
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
let s = MyServer(handle: { request in
    let route = routes.runParse(request)
    let sessionString = request.cookies.first { $0.0 == "sessionid" }?.1
    let sessionId = sessionString.flatMap { UUID(uuidString: $0) }
    return route?.interpret(sessionId: sessionId)
}, resourcePaths: resourcePaths)
try s.listen()


