import Foundation
import NIOWrapper

struct Session {
    var user: User
    var currentPath: String
}

struct User {
    var name: String
}

enum Node {
    case node(Element)
    case raw(String)
    // ...
}

struct Element {
    var name: String
    var children: [Node]

    func render() -> String {
        return "<\(name)>\(children.map { $0.render() }.joined(separator: " "))</\(name)>"
    }
}

extension Node {
    static func p(_ children: [Node]) -> Node {
        return .node(Element(name: "p", children: children))
    }
    
    static func div(_ children: [Node]) -> Node {
        return .node(Element(name: "div", children: children))
    }

    func render() -> String {
        switch self {
        case let .node(e):
            return e.render()
        case let .raw(str):
            return str
        }
    }
}

func layout(session: Session, _ node: Node) -> Node {
    return .div([
            .raw("<h1>Title</h1>"),
            .raw("Link to login with \(session.currentPath)"),
            node
        ])
}

func accountView(session: Session) -> Node {
    return
        layout(session: session, .p([.raw("Your account: \(session.user.name)")]))
}

func homePage(session: Session) -> Node {
    return layout(session: session, .p([.raw("The homepage")]))
}

typealias Response = NIOInterpreter

func interpret(session: Session, path: [String]) -> Response {
    if path == ["account"] {
        return .write(accountView(session: session).render())
    } else if path == [] {
        return .write(homePage(session: session).render())
    } else {
        return .write("Not found")
    }
}

let server = Server(resourcePaths: []) { request in
    let session  = Session(user: User(name: "Chris"), currentPath: "/" + request.path.joined(separator: "/"))
    let result = interpret(session: session, path: request.path)
    return result
}

try server.listen(port: 9999)
