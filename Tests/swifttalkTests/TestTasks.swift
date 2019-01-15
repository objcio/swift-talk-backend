//
//  TestTasks.swift
//  SwiftTalkTests
//
//  Created by Florian Kugler on 15-01-2019.
//

import Foundation
import XCTest
@testable import SwiftTalkServerLib

final class TaskTests: XCTestCase {
    override static func setUp() {
        pushTestEnv()
    }
    
    func testSyncTeamMembers() throws {
        func setupSession(user: Row<UserData>, numberOfTeamMembers: Int) {
            let session = TestURLSession { e in
                if e.request.matches(user.currentSubscription.request) {
                    return activeSubscription
                } else if e.request.matches(recurly.updateSubscription(activeSubscription, numberOfTeamMembers: numberOfTeamMembers).request) {
                    return activeSubscription
                } else {
                    XCTFail("Unexpected endpoint: \(e.request.httpMethod ?? "GET") \(e.request.url!)"); fatalError()
                }
            }
            let testDate = Date()
            pushGlobals(Globals(currentDate: { testDate }, urlSession: session))
        }
        
        func conn(user: Row<UserData>) -> Lazy<ConnectionProtocol> {
            return Lazy({ TestConnection { query in
                if query.matches(Row<UserData>.select(user.id)) {
                    return user as Any
                } else if query.matches(user.teamMembers) {
                    return [user, user]
                } else {
                    XCTFail()
                    fatalError()
                }
            } as ConnectionProtocol }, cleanup: { _ in })
        }

        // Team members of a normal user should all be billed
        var user = subscribedUser.user
        setupSession(user: user, numberOfTeamMembers: 2)
        try Task.syncTeamMembersWithRecurly(userId: user.id).interpret(conn(user: user)) { _ in }

        // Team members of a team manager should be billed minus one
        user = subscribedTeamManager.user
        setupSession(user: user, numberOfTeamMembers: 1)
        try Task.syncTeamMembersWithRecurly(userId: user.id).interpret(conn(user: user)) { _ in }
    }
}
