import Foundation

indirect enum RouteDescription {
    case constant(String)
    case parameter(String)
    case queryParameter(String)
    case external
    case joined(RouteDescription, RouteDescription)
    case choice(RouteDescription, RouteDescription)
    case empty
    case body
    case any
}

enum Endpoint {
    case external(URL)
    case relative(RelativePath)
    
    init(path: [String], query: [String: String] = [:]) {
        self = .relative(RelativePath(path: path, query: query))
    }
    
    var prettyPath: String {
        switch self {
        case let .external(url): return url.absoluteString
        case let .relative(p): return p.prettyPath
        }
    }
}

struct RelativePath {
    var path: [String]
    var query: [String: String]
    
    init(path: [String], query: [String: String] = [:]) {
        self.path = path
        self.query = query
    }

    var prettyPath: String {
        let components = NSURLComponents(string: "http://localhost")!
        components.queryItems = query.map { x in URLQueryItem(name: x.0, value: x.1.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)) }
        let q = components.query ?? ""
        return "/" + path.joined(separator: "/") + (q.isEmpty ? "" : "?\(q)")
    }
}

public struct Router<A> {
    fileprivate let parse: (inout Request) -> A?
    let print: (A) -> Endpoint?
    let description: RouteDescription
}

extension RouteDescription {
    var pretty: String {
        switch self {
        case .constant(let s): return s
        case .parameter(let p): return ":\(p)"
        case .any: return "*"
        case .empty: return ""
        case .body: return "<post body>"
        case .external: return "external"
        case let .queryParameter(name): return "?\(name)=*"
        case let .joined(lhs, rhs): return lhs.pretty + "/" + rhs.pretty
        case let .choice(lhs, rhs): return "choice(\(lhs.pretty), \(rhs.pretty))"
        }
    }
}

extension Router {
    func route(for request: Request) -> A? {
        var copy = request
        let result = parse(&copy)
        guard copy.path.isEmpty, copy.query.isEmpty else { return nil }
        return result
    }
}

extension Router where A: Equatable {
    init(_ value: A) {
        self.init(parse: { _ in value }, print: { x in
            guard value == x else { return nil }
            return Endpoint(path: [])
        }, description: .empty)
    }
    
    /// Constant string
    static func c(_ string: String, _ value: A) -> Router {
        return Router<()>.c(string) / Router(value)
    }
    
}

extension Router where A == URL {
    static var external: Router {
        return Router<URL>(parse: { _ in nil}, print: { Endpoint.external($0) }, description: .external)
    }
}

extension Router where A == () {
    /// Constant string
    static func c(_ string: String) -> Router {
        return Router(parse: { req in
            guard req.path.first == string else { return nil }
            req.path.removeFirst()
            return ()
        }, print: { _ in
            return Endpoint(path: [string])
        }, description: .constant(string))
    }
}

extension Router where A == Int {
    static func int() -> Router<Int> {
        return Router<String>.string().transform(Int.init, { "\($0)"}, { _ in .parameter("int") })
    }
}

extension Router where A == [String] {
    // eats up the entire path of a route
    static func path() -> Router<[String]> {
        return Router<[String]>(parse: { req in
            let result = req.path
            req.path.removeAll()
            return result
        }, print: { p in
            return Endpoint(path: p)
        }, description: .any)
    }
}

extension Router where A == String {
    static func string() -> Router<String> {
        return Router<String>(parse: { req in
            guard let f = req.path.first else { return nil }
            req.path.removeFirst()
            return f.removingPercentEncoding ?? ""
        }, print: { (str: String) in
            return Endpoint(path: [str.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!])
        }, description: .parameter("string"))
    }
    
    static func queryParam(name: String) -> Router<String> {
        return Router<String>(parse: { req in
            guard let x = req.query[name] else { return nil }
            req.query[name] = nil
            return x
        }, print: { (str: String) in
            return Endpoint(path: [], query: [name: str])
        }, description: .queryParameter(name))
    }
    
    static func optionalQueryParam(name: String) -> Router<String?> {
        return Router<String?>(parse: { req in
            guard let x = req.query[name] else { return .some(nil) }
            req.query[name] = nil
            return x
        }, print: { (str: String?) in
            return Endpoint(path: [], query: str == nil ? [:] : [name: str!])
        }, description: .queryParameter(name))
    }
}

extension Optional {
    func xor(_ value: Optional) -> Optional {
        if let v = self {
            assert(value == nil)
            return v
        }
        return value
    }
}

extension Router {
    func or(_ other: Router) -> Router {
        return Router(parse: { req in
            let state = req
            if let x = self.parse(&req), req.path.isEmpty { return x }
            req = state
            return other.parse(&req)
        }, print: { value in
            self.print(value) ?? other.print(value)
        }, description: .choice(description, other.description))
    }
}

func +(lhs: Endpoint, rhs: Endpoint) -> Endpoint {
    guard case let .relative(l) = lhs, case let .relative(r) = rhs else {
        fatalError("Endpoint mismatch: \(lhs) \(rhs)")
    }
    let query = l.query.merging(r.query, uniquingKeysWith: { _, _ in fatalError("Duplicate key") })
    return Endpoint(path: l.path + r.path, query: query)
}

extension Router {
    func transform<B>(_ to: @escaping (A) -> B?, _ from: @escaping (B) -> A?, _ f: ((RouteDescription) -> RouteDescription) = { $0 }) -> Router<B> {
        return Router<B>(parse: { (req: inout Request) -> B? in
            let result = self.parse(&req)
            return result.flatMap(to)
        }, print: { value in
            from(value).flatMap(self.print)
        }, description: f(description))
    }
}
// append two routes
func /<A,B>(lhs: Router<A>, rhs: Router<B>) -> Router<(A,B)> {
    return Router(parse: { req in
        guard let f = lhs.parse(&req), let x = rhs.parse(&req) else { return nil }
        return (f, x)
    }, print: { value in
        guard let x = lhs.print(value.0), let y = rhs.print(value.1) else { return nil }
        return x + y
    }, description: .joined(lhs.description, rhs.description))
}

func /<A>(lhs: Router<()>, rhs: Router<A>) -> Router<A> {
    return (lhs / rhs).transform({ x, y in y }, { ((), $0) })
}
