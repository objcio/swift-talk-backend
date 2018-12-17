
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
    case _writeHTML(node: SwiftTalkServerLib.Node, status: HTTPResponseStatus)
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

extension TestInterpreter: SwiftTalkInterpreter {
    
}

let testCSRF = CSRFToken(UUID())

extension TestInterpreter: HTML {
    static func write(_ html: SwiftTalkServerLib.Node, status: HTTPResponseStatus) -> TestInterpreter {
        return ._writeHTML(node: html, status: status)
    }
    
    static func withCSRF(_ cont: @escaping (CSRFToken) -> TestInterpreter) -> TestInterpreter {
        return cont(testCSRF)
    }
}

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

extension TestInterpreter: HasSession {
    static func withSession(_ cont: @escaping (Session?) -> TestInterpreter) -> TestInterpreter {
        return ._withSession(cont)
    }
}


final class FlowTests: XCTestCase {
    override static func setUp() {
        pushTestEnv()
        
    }
    
    func testExample() throws {
//        pushTestConnection(TestConnection { query in
//            fatalError("\(query)")
//        })
        testPlans = [
            Plan(plan_code: "monthly_plan", name: "Monthly Plan", description: nil, plan_interval_length: 1, plan_interval_unit: .months, unit_amount_in_cents: 100, total_billing_cycles: nil),
            Plan(plan_code: "yearly_plan", name: "Yearly Plan", description: nil, plan_interval_length: 12, plan_interval_unit: .months, unit_amount_in_cents: 1200, total_billing_cycles: nil)
        ]
        let route = Route.subscribe
        let result: TestInterpreter = try route.interpret()
        print(result)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
