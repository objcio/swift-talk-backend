import XCTest

extension FlowTests {
    static let __allTests = [
        ("testNewSubscription", testNewSubscription),
        ("testSubscription", testSubscription),
    ]
}

extension RouteTests {
    static let __allTests = [
        ("testBasicRoutes", testBasicRoutes),
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
