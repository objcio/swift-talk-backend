import Foundation

enum HTTPMethod: String {
    case post = "POST"
    case get = "GET"
}

struct Request {
    var path: [String]
    var query: [String:String]
    var method: HTTPMethod
    var cookies: [(String, String)]
    var body: Data?
    var prettyPath: String {
        var components = NSURLComponents(string: "http://localhost")!
        components.queryItems = query.map { x in URLQueryItem(name: x.0, value: x.1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)) }
        let q = components.query ?? ""
        return "/" + path.joined(separator: "/") + (q.isEmpty ? "" : "?\(q)")
    }
}

indirect enum RouteDescription {
    case constant(String)
    case parameter(String)
    case queryParameter(String)
    case joined(RouteDescription, RouteDescription)
    case choice(RouteDescription, RouteDescription)
    case empty
    case any
}

public struct Route<A> {
    let parse: (inout Request) -> A?
    let print: (A) -> Request?
    let description: RouteDescription
}

extension RouteDescription {
    var pretty: String {
        switch self {
        case .constant(let s): return s
        case .parameter(let p): return ":\(p)"
        case .any: return "*"
        case .empty: return ""
        case let .queryParameter(name): return "?\(name)=*"
        case let .joined(lhs, rhs): return lhs.pretty + "/" + rhs.pretty
        case let .choice(lhs, rhs): return "choice(\(lhs.pretty), \(rhs.pretty))"
	}
    }
}

extension Route {
    func runParse(_ r: Request) -> A? {
        var copy = r
        let result = parse(&copy)
        guard copy.path.isEmpty, copy.query.isEmpty else { return nil }
        return result
    }
}

extension Route where A: Equatable {
    init(_ value: A) {
        self.init(parse: { _ in value }, print: { x in
            guard value == x else { return nil }
            return Request(path: [], query: [:], method: .get, cookies: [], body: nil)
        }, description: .empty)
    }
    
    /// Constant string
    static func c(_ string: String, _ value: A) -> Route {
        return Route<()>.c(string) / Route(value)
    }
}

extension Route where A == () {
    /// Constant string
    static func c(_ string: String) -> Route {
        return Route(parse: { req in
            guard req.path.first == string else { return nil }
            req.path.removeFirst()
            return ()
        }, print: { _ in
            return Request(path: [string], query: [:], method: .get, cookies: [], body: nil)
        }, description: .constant(string))
    }
}

extension Route where A == Int {
    static func int() -> Route<Int> {
        return Route<String>.string().transform(Int.init, { "\($0)"}, { _ in .parameter("int") })
    }
}

extension Route where A == [String] {
    // eats up the entire path of a route
    static func path() -> Route<[String]> {
        return Route<[String]>(parse: { req in
            let result = req.path
            req.path.removeAll()
            return result
        }, print: { p in
            return Request(path: p, query: [:], method: .get, cookies: [], body: nil)
        }, description: .any)
    }
}

extension Route where A == String {
    static func string() -> Route<String> {
        // todo escape
        return Route<String>(parse: { req in
            guard let f = req.path.first else { return nil }
            req.path.removeFirst()
            return f
        }, print: { (str: String) in
            return Request(path: [str], query: [:], method: .get, cookies: [], body: nil)
        }, description: .parameter("string"))
    }
    
    static func queryParam(name: String) -> Route<String> {
        return Route<String>(parse: { req in
            guard let x = req.query[name] else { return nil }
            req.query[name] = nil
            return x
        }, print: { (str: String) in
            return Request(path: [], query: [name: str], method: .get, cookies: [], body: nil)
        }, description: .queryParameter(name))
    }
    
    static func optionalQueryParam(name: String) -> Route<String?> {
        return Route<String?>(parse: { req in
            guard let x = req.query[name] else { return .some(nil) }
            req.query[name] = nil
            return x
        }, print: { (str: String?) in
            return Request(path: [], query: str == nil ? [:] : [name: str!], method: .get, cookies: [], body: nil)
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

extension Route {
    func or(_ other: Route) -> Route {
        return Route(parse: { req in
            let state = req
            if let x = self.parse(&req), req.path.isEmpty { return x }
            req = state
            return other.parse(&req)
        }, print: { value in
            self.print(value) ?? other.print(value)
        }, description: .choice(description, other.description))
    }
}
func +(lhs: Request, rhs: Request) -> Request {
    let body = lhs.body.xor(rhs.body)
    let query = lhs.query.merging(rhs.query, uniquingKeysWith: { _,_ in fatalError("Duplicate key") })
    return Request(path: lhs.path + rhs.path, query: query, method: lhs.method, cookies: lhs.cookies + rhs.cookies, body: body)
}

extension Route {
    func transform<B>(_ to: @escaping (A) -> B?, _ from: @escaping (B) -> A?, _ f: ((RouteDescription) -> RouteDescription) = { $0 }) -> Route<B> {
        return Route<B>(parse: { (req: inout Request) -> B? in
            let result = self.parse(&req)
            return result.flatMap(to)
        }, print: { value in
            from(value).flatMap(self.print)
        }, description: f(description))
    }
}
// append two routes
func /<A,B>(lhs: Route<A>, rhs: Route<B>) -> Route<(A,B)> {
    return Route(parse: { req in
        guard let f = lhs.parse(&req), let x = rhs.parse(&req) else { return nil }
        return (f, x)
    }, print: { value in
        guard let x = lhs.print(value.0), let y = rhs.print(value.1) else { return nil }
        return x + y
    }, description: .joined(lhs.description, rhs.description))
}

func /<A>(lhs: Route<()>, rhs: Route<A>) -> Route<A> {
    return (lhs / rhs).transform({ x, y in y }, { ((), $0) })
}
