import Foundation

enum HTTPMethod: String {
    case post = "POST"
    case get = "GET"
}

struct Request {
    var path: [String]
    var query: [String:String]
    var method: HTTPMethod
    var body: Data?
}

enum RouteDescription {
    case constant(String)
    case parameter(String)
}

public struct SingleRoute<A> {
    let parse: (inout Request) -> A?
    let print: (A) -> Request
    let description: [RouteDescription]
}

extension SingleRoute {
    func runParse(_ r: Request) -> A? {
        var copy = r
        let result = parse(&copy)
        guard copy.path.isEmpty, copy.query.isEmpty else { return nil }
        return result
    }
}

extension SingleRoute {
    init(_ value: A) {
        self.init(parse: { _ in value }, print: { _ in Request(path: [], query: [:], method: .get, body: nil)}, description: [])
    }
    
    /// Constant string
    static func c(_ string: String, _ value: A) -> SingleRoute {
        return SingleRoute<()>.c(string) / SingleRoute(value)
    }
}

extension SingleRoute where A == () {
    /// Constant string
    static func c(_ string: String) -> SingleRoute {
        return SingleRoute(parse: { req in
            guard req.path.first == string else { return nil }
            req.path.removeFirst()
            return ()
        }, print: { _ in
            return Request(path: [string], query: [:], method: .get, body: nil)
        }, description: [.constant(string)])
    }
}

extension SingleRoute where A == Int {
    static func int() -> SingleRoute<Int> {
        return SingleRoute<String>.string().transform(Int.init, { "\($0)"}, { _ in [.parameter("int")] })
    }
}

extension SingleRoute where A == String {
    static func string() -> SingleRoute<String> {
        // todo escape
        return SingleRoute<String>(parse: { req in
            guard let f = req.path.first else { return nil }
            req.path.removeFirst()
            return f
        }, print: { (str: String) in
            return Request(path: [str], query: [:], method: .get, body: nil)
        }, description: [.parameter("string")])
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

func +(lhs: Request, rhs: Request) -> Request {
    let body = lhs.body.xor(rhs.body)
    let query = lhs.query.merging(rhs.query, uniquingKeysWith: { _,_ in fatalError("Duplicate key") })
    return Request(path: lhs.path + rhs.path, query: query, method: lhs.method, body: body)
}

extension SingleRoute {
    func transform<B>(_ to: @escaping (A) -> B?, _ from: @escaping (B) -> A, _ f: (([RouteDescription]) -> [RouteDescription]) = { $0 }) -> SingleRoute<B> {
        return SingleRoute<B>(parse: { req in
            self.parse(&req).flatMap(to)
        }, print: { value in
            self.print(from(value))
        }, description: f(description))
    }
}
// append two routes
func /<A,B>(lhs: SingleRoute<A>, rhs: SingleRoute<B>) -> SingleRoute<(A,B)> {
    return SingleRoute(parse: { req in
        guard let f = lhs.parse(&req), let x = rhs.parse(&req) else { return nil }
        return (f, x)
    }, print: { value in
        lhs.print(value.0) + rhs.print(value.1)
    }, description: lhs.description + rhs.description)
}

func /<A>(lhs: SingleRoute<()>, rhs: SingleRoute<A>) -> SingleRoute<A> {
    return (lhs / rhs).transform({ x, y in y }, { ((), $0) })
}

typealias Routes<A> = [SingleRoute<A>]
