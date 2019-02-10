
import XCTest
import Base
@testable import SwiftTalkServerLib
import Database
import WebServer


struct QueryAndResult {
    let query: Query<Any>
    let response: Any
    init<A>(query: Query<A>, response: A) {
        self.query = query.map { $0 }
        self.response = response
    }
    
    init(_ query: Query<()>) {
        self.query = query.map { $0 }
        self.response = ()
    }
}

extension QueryAndResult: Equatable {
    static func ==(l: QueryAndResult, r: QueryAndResult) -> Bool {
        return l.query.query == r.query.query
    }
}

struct Flow {
    let session: Session?
    let currentPage: TestInterpreter

    private static func run(_ session: Session?, _ route: Route, connection: TestConnection = TestConnection([]), assertQueriesDone: Bool = true, _ file: StaticString, _ line: UInt) throws -> TestInterpreter {
        let lazyConn: Lazy<ConnectionProtocol> = Lazy({ connection }, cleanup: { _ in })
        let env = STRequestEnvironment(route: route, hashedAssetName: { $0 }, buildSession: { session }, connection: lazyConn, resourcePaths: [])
        let reader: Reader<STRequestEnvironment, TestInterpreter> = try route.interpret()
        let result = reader.run(env)
        if assertQueriesDone { connection.assertDone() }
        return result
    }
    
    static func landingPage(session: Session?, file: StaticString = #file, line: UInt = #line, _ route: Route) throws -> Flow {
        return try Flow(session: session, currentPage: run(session, route, file, line))
    }
    
    func verify(cond: (TestInterpreter) -> ()) {
        cond(currentPage)
    }
    
    func click(_ route: Route, file: StaticString = #file, line: UInt = #line, _ cont: (Flow) throws -> ()) throws {
        testLinksTo(currentPage, route: route)
        try cont(Flow(session: session, currentPage: Flow.run(session, route, file, line)))
    }
    
    func followRedirect(to action: Route, expectedQueries: [QueryAndResult] = [], file: StaticString = #file, line: UInt = #line,  _ then: (Flow) throws -> ()) throws -> () {
        guard case let TestInterpreter._redirect(path: path, headers: _) = currentPage else {
            XCTFail("Expected redirect"); return
        }
        guard action.path == path else {
            XCTFail("Expected \(action), got \(path)"); return
        }
        
        try then(Flow(session: session, currentPage: Flow.run(session, action, connection: TestConnection(expectedQueries), file, line)))
    }
    
    func fillForm(to action: Route, data: [String:String] = [:], expectedQueries: [QueryAndResult] = [], file: StaticString = #file, line: UInt = #line,  _ then: (Flow) throws -> ()) throws {
        guard let f = currentPage.forms().first(where: { $0.action == action }) else {
            XCTFail("Couldn't find a form with action \(action)", file: file, line: line)
            return
        }
        var postData = Dictionary(f.inputs, uniquingKeysWith: { $1 })
        for (key,_) in data {
            XCTAssert(postData[key] != nil)
        }
        let conn = TestConnection(expectedQueries)
        guard case let ._withPostData(cont) = try Flow.run(session, action, connection: conn, assertQueriesDone: false, file, line) else {
            XCTFail("Expected post handler", file: file, line: line)
            return
        }
        let theData = postData.merging(data, uniquingKeysWith: { $1 }).map { (key, value) in "\(key)=\(value.escapeForAttributeValue)"}.joined(separator: "&").data(using: .utf8)!
        let nextPage = cont(theData)
        conn.assertDone()
        try then(Flow(session: session, currentPage: nextPage))
    }
    
    func withSession(_ session: Session?, _ then: (Flow) throws -> ()) throws {
        return try then(Flow(session: session, currentPage: currentPage))
    }
}

final class FlowTests: XCTestCase {
    
    override static func setUp() {
        pushTestEnv()
        let testDate = Date()
        pushGlobals(Globals(currentDate: { testDate }))
    }
    
    func run(_ route: Route) -> (Session?) throws -> TestInterpreter {
        return { (session: Session?) in
            let lazyConn: Lazy<ConnectionProtocol> = Lazy({ TestConnection() }, cleanup: { _ in })
            let env = STRequestEnvironment(route: route, hashedAssetName: { $0 }, buildSession: { session }, connection: lazyConn, resourcePaths: [])
            let reader: Reader<STRequestEnvironment, TestInterpreter> = try route.interpret()
            return reader.run(env)
        }
    }
    
    func testSubscription() throws {
        // todo test coupon codes
        testPlans = plans
        
        let subscribeWithoutASession = try Flow.landingPage(session: nil, .signup(.subscribe))
        subscribeWithoutASession.verify { page in
            testLinksTo(page, route: .login(.login(continue: .subscription(.new(couponCode: nil, team: false)))))
        }
        
        let notSubscribed = try Flow.landingPage(session: nonSubscribedUser, .signup(.subscribe))
        try notSubscribed.click(.subscription(.new(couponCode: nil, team: false)), {
            var confirmedSess = $0.session!
            confirmedSess.user.data.confirmedNameAndEmail = true
            try $0.fillForm(to: .account(.register(couponCode: nil, team: false)), expectedQueries: [
                QueryAndResult(query: confirmedSess.user.update(), response: ())
            ], {
                try $0.withSession(confirmedSess) {
                    try $0.followRedirect(to: .subscription(.new(couponCode: nil, team: false)), expectedQueries: [
                        QueryAndResult(Task.unfinishedSubscriptionReminder(userId: confirmedSess.user.id).schedule(weeks: 1)),
                        QueryAndResult(confirmedSess.user.update())
                    ], {
                        print($0.currentPage)
                    })
                }
            })
        })
    }

    func testTeamSubscription() throws {
        testPlans = plans
        let subscribeWithoutASession = try Flow.landingPage(session: nil, .signup(.subscribeTeam))
        subscribeWithoutASession.verify { page in
            testLinksTo(page, route: .login(.login(continue: .subscription(.new(couponCode: nil, team: true)))))
        }

        let notSubscribed = try Flow.landingPage(session: nonSubscribedUser, .signup(.subscribeTeam))
        try notSubscribed.click(.subscription(.new(couponCode: nil, team: true)), {
            var confirmedSess = $0.session!
            confirmedSess.user.data.confirmedNameAndEmail = true
            confirmedSess.user.data.role = .teamManager
            try $0.fillForm(to: .account(.register(couponCode: nil, team: true)), expectedQueries: [
                QueryAndResult(query: confirmedSess.user.update(), response: ())
            ], {
                try $0.withSession(confirmedSess) {
                    try $0.followRedirect(to: .subscription(.new(couponCode: nil, team: true)), expectedQueries: [
                        QueryAndResult(Task.unfinishedSubscriptionReminder(userId: confirmedSess.user.id).schedule(weeks: 1)),
                        QueryAndResult(confirmedSess.user.update())
                    ], {
                        print($0.currentPage)
                    })
                }
            })
        })
    }

    func testNewSubscription() throws {
        testPlans = plans
        let noSession = try Flow.landingPage(session: nil, .subscription(.new(couponCode: nil, team: false)))
        noSession.verify{ $0.testIsError() }

        let withSession = try Flow.landingPage(session: nonSubscribedUser, .subscription(.new(couponCode: nil, team: false)))
        withSession.verify {
            XCTAssertEqual($0.forms().first?.action, .account(.register(couponCode: nil, team: false)))
        }
    }
    

    static var allTests = [
        ("testSubscription", testSubscription),
        ("testNewSubscription", testNewSubscription),
    ]
}
