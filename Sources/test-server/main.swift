import Foundation
import NIOWrapper

struct Session {
    var user: User
    var currentPath: String
}

struct User {
    var name: String
}

enum Node<Input> {
    case node(Element<Input>)
    case raw(String)
    case withInput((Input) -> Node)
    // ...
}

struct Element<Input> {
    var name: String
    var children: [Node<Input>]

    func render(input: Input) -> String {
        return "<\(name)>\(children.map { $0.render(input: input) }.joined(separator: " "))</\(name)>"
    }
}

extension Node {
    static func p(_ children: [Node]) -> Node {
        return .node(Element(name: "p", children: children))
    }
    
    static func div(_ children: [Node]) -> Node {
        return .node(Element(name: "div", children: children))
    }

    func render(input: Input) -> String {
        switch self {
        case let .node(e):
            return e.render(input: input)
        case let .raw(str):
            return str
        case let .withInput(f):
            return f(input).render(input: input)
        }
    }
}

typealias SNode = Node<Session>

func layout(_ node: SNode) -> SNode {
    return .div([
            .raw("<h1>Title</h1>"),
            Node.withInput { session in .raw("Link to login with \(session.currentPath)") },
            node
        ])
}

func accountView() -> SNode {
    return
        layout(.p([Node.withInput { session in .raw("Your account: \(session.user.name)") }]))
}

func homePage() -> SNode {
    return layout(.p([.raw("The homepage")]))
}

struct Reader<Value, Result> {
    let run: (Value) -> Result
}

protocol ResponseProtocol {
    static func write(_ s: String, status: HTTPResponseStatus, headers: [String: String]) -> Self
}

extension ResponseProtocol {
    static func write(_ s: String) -> Self {
        return .write(s, status: .ok, headers: [:])
    }
}

extension Reader where Result: ResponseProtocol {
    static func write(_ node: Node<Value>) -> Reader {
        return Reader { session in
            return .write(node.render(input: session))
        }
    }
}

extension NIOInterpreter: ResponseProtocol { }

typealias Response<I: ResponseProtocol> = Reader<Session, I>

func interpret<I>(path: [String]) -> Response<I> {
    if path == ["account"] {
        return .write(accountView())
    } else if path == [] {
        return .write(homePage())
    } else {
        return .write(.raw("Not found"))
    }
}

let server = Server(resourcePaths: []) { request in
    let session  = Session(user: User(name: "Chris"), currentPath: "/" + request.path.joined(separator: "/"))
    let result: Reader<Session, NIOInterpreter> = interpret(path: request.path)
    return result.run(session)
}

//try server.listen(port: 9999)

enum TestInterpreter: ResponseProtocol {
    case _write(String, status: HTTPResponseStatus, headers: [String: String])

    static func write(_ s: String, status: HTTPResponseStatus, headers: [String : String]) -> TestInterpreter {
        return ._write(s, status: status, headers: headers)
    }
}

func test() {
    let session  = Session(user: User(name: "Florian"), currentPath: "/")
    let result: TestInterpreter = interpret(path: ["account"]).run(session)
    guard case let ._write(s, status, headers) = result else {
        assert(false)
    }
    assert(s.contains("Chris"))
}

test()
