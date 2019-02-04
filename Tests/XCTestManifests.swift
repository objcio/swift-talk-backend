import XCTest

extension FlowTests {
    static let __allTests = [
        ("testSubscription", testSubscription),
        ("testTeamSubscription", testTeamSubscription),
    ]
}

extension RouteTests {
    static let __allTests = [
        ("testBasicRoutes", testLandingPages),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(FlowTests.__allTests),
        testCase(RouteTests.__allTests),
    ]
}
#endif
