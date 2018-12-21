import XCTest

extension FlowTests {
    static let __allTests = [
        ("testNewSubscription", testNewSubscription),
        ("testSubscription", testSubscription),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(FlowTests.__allTests),
    ]
}
#endif
