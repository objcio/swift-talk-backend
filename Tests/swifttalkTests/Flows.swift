
import XCTest
import NIOHTTP1
@testable import SwiftTalkServerLib

enum TestInterpreter: Interpreter {
    case _write(String, status: HTTPResponseStatus, headers: [String:String])
    case _writeData(Data, status: HTTPResponseStatus, headers: [String:String])
    case _writeFile(path: String, maxAge: UInt64?)
    case _onComplete(promise: Promise<Any>, do: (Any) -> TestInterpreter)
    case _withPostData(do: (Data) -> TestInterpreter)
    case _redirect(path: String, headers: [String:String])
    case _writeHTML(SwiftTalkServerLib.ANode<()>, status: HTTPResponseStatus)
    case _execute(Query<Any>, cont: (Either<Any, Error>) -> TestInterpreter)
    case _withSession((Session?) -> TestInterpreter)

    static func write(_ string: String, status: HTTPResponseStatus, headers: [String : String]) -> TestInterpreter {
        return ._write(string, status: status, headers: headers)
    }

    static func write(_ data: Data, status: HTTPResponseStatus, headers: [String : String]) -> TestInterpreter {
        return ._writeData(data, status: status, headers: headers)
    }

    static func writeFile(path: String, maxAge: UInt64?) -> TestInterpreter {
        return ._writeFile(path: path, maxAge: maxAge)
    }
    
    static func write(html: ANode<()>, status: HTTPResponseStatus) -> TestInterpreter {
        return ._writeHTML(html, status: status)
    }

    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> TestInterpreter) -> TestInterpreter {
        return ._onComplete(promise: promise.map { $0 }, do: { x in cont(x as! A) })
    }

    static func withPostData(do cont: @escaping (Data) -> TestInterpreter) -> TestInterpreter {
        return ._withPostData(do: cont)
    }

    static func redirect(path: String, headers: [String : String]) -> TestInterpreter {
        return ._redirect(path: path, headers: headers)
    }
}

extension TestInterpreter: SwiftTalkInterpreter {}

let testCSRF = CSRFToken(UUID())

struct TestErr: Error { }

import PostgreSQL
extension TestInterpreter: HasDatabase {
    static func withConnection(_ cont: @escaping (Either<Connection, Error>) -> TestInterpreter) -> TestInterpreter {
        return cont(.right(TestErr()))
    }

    static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) -> TestInterpreter) -> TestInterpreter {
        return ._execute(query.map { $0 }, cont: { x in
        switch x {
        case let .left(any): return cont(.left(any as! A))
        case let .right(r): return cont(.right(r))
            }
        })
    }
}

var session: Session? = nil

struct TestConnection: ConnectionProtocol {
    let _execute: (String, [PostgreSQL.Node]) -> PostgreSQL.Node = { _,_ in fatalError() }
    let _eQuery: (Query<Any>) throws -> Any
    init(query: @escaping (Query<Any>) throws -> Any = { _ in fatalError() }) {
        self._eQuery = query
    }
    func execute(_ query: String, _ values: [PostgreSQL.Node]) throws -> PostgreSQL.Node {
        return _execute(query, values)
    }
    
    func execute<A>(_ query: Query<A>) throws -> A {
        return try _eQuery(query.map { $0 }) as! A
    }
}

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

extension TestInterpreter {
    func linkTargets(file: StaticString = #file, line: UInt = #line) -> [Route] {
        guard case let ._writeHTML(node, status: .ok) = self else { XCTFail("Expected HTML", file: file, line: line); return [] }
        return node.linkTargets().compactMap( { Route(Request($0))})
    }
    
    func forms(file: StaticString = #file, line: UInt = #line) -> [(action: Route, inputs: [(String,String)])] {
        guard case let ._writeHTML(node, status: .ok) = self else { XCTFail("Expected HTML", file: file, line: line); return [] }
        return node.forms().compactMap { (a, inputs) in
            guard let action = Route(Request(a)) else { return nil }
            return (action, inputs)
        }
    }
    
    func testIsError(file: StaticString = #file, line: UInt = #line) {
        guard case let ._writeHTML(_, status: status) = self else { XCTFail("Expected HTML", file: file, line: line); return }
        XCTAssert(status.code >= 400, file: file, line: line)
    }
}

func testLinksTo(_ i: TestInterpreter, route: Route, file: StaticString = #file, line: UInt = #line) {
    let routes = i.linkTargets()
    XCTAssert(routes.contains { $0 == route }, "Expected \(route) in \(routes)", file: file, line: line)
}

let plans = [
    Plan(plan_code: "monthly_plan", name: "Monthly Plan", description: nil, plan_interval_length: 1, plan_interval_unit: .months, unit_amount_in_cents: 100, total_billing_cycles: nil),
    Plan(plan_code: "yearly_plan", name: "Yearly Plan", description: nil, plan_interval_length: 12, plan_interval_unit: .months, unit_amount_in_cents: 1200, total_billing_cycles: nil)
]

let noConnection: Lazy<Connection> = Lazy<Connection>({ fatalError() }, cleanup: { _ in () })

let nonSubscribedUser = Session(sessionId: UUID(), user: Row(id: UUID(), data: UserData(email: "test@example.com", avatarURL: "", name: "Tester")), masterTeamUser: nil, gifter: nil)
let subscribedUser = Session(sessionId: UUID(), user: Row(id: UUID(), data: UserData(email: "test@example.com", avatarURL: "", name: "Tester", subscriber: true)), masterTeamUser: nil, gifter: nil)

func TestUnwrap<A>(_ value: A?, file: StaticString = #file, line: UInt = #line) throws -> A {
    guard let x = value else {
        XCTFail(file: file, line: line)
        throw TestErr()
    }
    return x
}

final class FlowTests: XCTestCase {
    
    override static func setUp() {
        pushTestEnv()
        
    }
    
    func run(_ route: Route) -> (Session?) throws -> TestInterpreter {
        return { (session: Session?) in
            let env = RequestEnvironment(route: route, hashedAssetName: { $0 }, buildSession: { session }, connection: noConnection, resourcePaths: [])
            let i: Reader<RequestEnvironment, TestInterpreter> = try route.interpret()
            return i.run(env)
        }
    }
    
    func testSubscription() throws {
        testPlans = plans
        
        // todo test coupon codes
        let i = run(.subscribe)
        // Not logged in
        try testLinksTo(i(nil), route: .login(continue: .subscription(.new(couponCode: nil))))
        // Logged in
        try testLinksTo(i(nonSubscribedUser), route: .subscription(.new(couponCode: nil)))
        // Subscriber
        try testLinksTo(i(subscribedUser), route: .account(.profile))
    }
    
    func testNewSubscription() throws {
        testPlans = plans
        
        // todo test coupon codes
        let i = run(.subscription(.new(couponCode: nil)))
        // Not logged in
        try i(nil).testIsError()
        
        let form = try TestUnwrap(i(nonSubscribedUser).forms().first)
        XCTAssertEqual(form.action, .account(.register(couponCode: nil)))
        
        try print(i(subscribedUser))
    }
    
    // IDEA we can have a "click" test that verifies a route is present in the current page, and then proceeds to test that link. this could build up a tree structure of tests (for different combinations). we could branch out if there are multiple choices on a page.
    
    
//    func testRoutes() throws {
//        let r = try routesReachable(startingFrom: .subscribe, session: nil)
//        print(r)
//    }
    
    //    func routesReachable(startingFrom: Route, session: Session?) throws -> [Route] {
    //        var routesChecked: [Route] = []
    //
    //        func helper(queue: inout [Route]) throws {
    //            while let r = queue.popLast() {
    //                guard !routesChecked.contains(r) else { continue }
    //                routesChecked.append(r)
    //                let rendered: TestInterpreter
    //                switch r {
    //                case .home: fatalError()
    //                case .subscribe:
    //
    //                default: fatalError("\(r)")
    //                }
    //                queue.append(contentsOf: rendered.linkTargets())
    //            }
    //        }
    //        var queue = [startingFrom]
    //        try helper(queue: &queue)
    //        return routesChecked
    //    }


    static var allTests = [
        ("testSubscription", testSubscription),
        ("testNewSubscription", testNewSubscription),
    ]
}
