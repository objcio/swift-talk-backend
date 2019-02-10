import XCTest

extension FlowTests {
    static let __allTests = [
        ("testNewSubscription", testNewSubscription),
        ("testSubscription", testSubscription),
        ("testTeamSubscription", testTeamSubscription),
    ]
}

extension RouteTests {
    static let __allTests = [
        ("testLandingPages", testLandingPages),
    ]
}

extension TaskTests {
    static let __allTests = [
        ("testSyncTeamMembersBillsAllTeamMembersForStandardUser", testSyncTeamMembersBillsAllTeamMembersForStandardUser),
        ("testSyncTeamMembersBillsMinusOneTeamMembersForTeamManager", testSyncTeamMembersBillsMinusOneTeamMembersForTeamManager),
    ]
}

#if !os(macOS)
public func __allTests() -> [XCTestCaseEntry] {
    return [
        testCase(FlowTests.__allTests),
        testCase(RouteTests.__allTests),
        testCase(TaskTests.__allTests),
    ]
}
#endif
