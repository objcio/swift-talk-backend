import Foundation
import NIO
import NIOHTTP1
import PostgreSQL

enum Accept: String {
    case json = "application/json"
}

struct RemoteEndpoint<A> {
    var request: URLRequest
    var parse: (Data) -> A?
    
    init(get: URL, accept: Accept? = nil, query: [String:String], parse: @escaping (Data) -> A?) {
        var comps = URLComponents(string: get.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        if let a = accept {
            request.setValue(a.rawValue, forHTTPHeaderField: "Accept")
        }
        self.parse = parse
    }
    
    init(post: URL, accept: String? = nil, query: [String:String], parse: @escaping (Data) -> A?) {
        var comps = URLComponents(string: post.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        request.httpMethod = "POST"
        if let a = accept {
            request.setValue(a, forHTTPHeaderField: "Accept")
        }
        self.parse = parse
    }
}

extension RemoteEndpoint where A: Decodable {
    /// Parses the result as JSON
    init(post: URL, query: [String:String]) {
        var comps = URLComponents(string: post.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        request.setValue(Accept.json.rawValue, forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        self.parse = { data in
            return try? JSONDecoder().decode(A.self, from: data)
        }
    }
}

extension URLSession {
    func load<A>(_ e: RemoteEndpoint<A>, callback: @escaping (A?) -> ()) {
        dataTask(with: e.request, completionHandler: { data, resp, err in
            guard let d = data else { callback(nil); return }
            return callback(e.parse(d))
        }).resume()
    }
}


func readDotEnv() -> [String:String] {
    guard let c = try? String(contentsOfFile: ".env") else { return [:] }
    return Dictionary(c.split(separator: "\n").compactMap { $0.keyAndValue }, uniquingKeysWith: { $1 })
}
let env: [String:String] = readDotEnv().merging(ProcessInfo.processInfo.environment, uniquingKeysWith: { $1 })
assert(env["GITHUB_CLIENT_ID"] != nil)
assert(env["GITHUB_CLIENT_SECRET"] != nil)
assert(env["GITHUB_CLIENT_SECRET"] != nil)

struct Github {
    static var clientId: String { return env["GITHUB_CLIENT_ID"]! }
    static var clientSecret: String { return env["GITHUB_CLIENT_SECRET"]! }
    
    static let contentType = "application/json"
    
    struct AccessTokenResponse: Codable, Equatable {
        var access_token: String
        var token_type: String
        var scope: String
    }
    
    let accessToken: String
    init(_ accessToken: String) {
        self.accessToken = accessToken
    }

    static func getAccessToken(_ code: String) -> RemoteEndpoint<AccessTokenResponse> {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        let query = [
            "client_id": Github.clientId,
            "client_secret": Github.clientSecret,
            "code": code,
            "accept": "json"
        ]
        return RemoteEndpoint(post: url, query: query)
    }
    
    func getProfile() -> RemoteEndpoint<String> {
        let url = URL(string: "https://api.github.com/user")!
        let query = ["access_token": accessToken]
        return RemoteEndpoint(get: url, accept: .json, query: query, parse: { String(data: $0, encoding: .utf8)})
    }
}

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
    case episodes
    case version
    case sitemap
    case imprint
    case subscribe
    case collections
    case login
    case githubCallback(String)
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

let callback: Route<MyRoute> = .c("users") / .c("auth") / .c("github") / .c("callback") / (Route<String>.queryParam(name: "code").transform({ MyRoute.githubCallback($0) }, { r in
    guard case let .githubCallback(x) = r else { return nil }
    return x
}))

let routes: Route<MyRoute> = [
    Route(.home),
    .c("version", .version),
    .c("books", .books), // todo absolute url
    .c("issues", .issues), // todo absolute url
    .c("episodes", .episodes),
    .c("sitemap", .sitemap),
    .c("subscribe", .subscribe),
    .c("imprint", .imprint),
    .c("users") / .c("auth") / .c("github", .login),
    callback,
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
        return e.sorted { $0.number > $1.number }

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
            return I.onComplete(callback: { cb in
                URLSession.shared.load(Github.getAccessToken(code), callback: { token in
                    cb(token?.access_token)
                })
            }, do: { token in
                guard let t = token else { return .write("No access") }
                return I.onComplete(callback: { cb in
                    URLSession.shared.load(Github(t).getProfile(), callback: cb)
                }, do: { str in
                    I.write(str ?? "no profile")
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

//print(siteMap(routes))
sanityCheck()
let s = MyServer(parse: { routes.runParse($0) }, interpret: { $0.interpret() }, resourcePaths: resourcePaths)
try s.listen()

