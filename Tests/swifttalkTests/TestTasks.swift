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
    
    func setupGlobals(session: URLSessionProtocol) {
        let testDate = Date()
        pushGlobals(Globals(currentDate: { testDate }, urlSession: session))
    }

    func teamMembersURLSession(user: Row<UserData>, numberOfTeamMembers: Int) -> TestURLSession {
        return TestURLSession([
            EndpointAndResult(endpoint: user.currentSubscription, response: activeSubscription),
            EndpointAndResult(endpoint: recurly.updateSubscription(activeSubscription, numberOfTeamMembers: numberOfTeamMembers), response: activeSubscription)
        ])
    }
    
    func syncTeamMembersQueries(user: Row<UserData>) -> [QueryAndResult] {
        return [
            QueryAndResult(query: Row<UserData>.select(user.id), response: user),
            QueryAndResult(query: user.teamMembers, response: [user, user])
        ]
    }

    func testSyncTeamMembersBillsAllTeamMembersForStandardUser() throws {
        let user = subscribedUser.user
        let urlSession = teamMembersURLSession(user: user, numberOfTeamMembers: 2)
        setupGlobals(session: urlSession)
        let conn = TestConnection(syncTeamMembersQueries(user: user))
        try Task.syncTeamMembersWithRecurly(userId: user.id).interpret(conn.lazy) { _ in }
        conn.assertDone()
        urlSession.assertDone()
    }

    func testSyncTeamMembersBillsMinusOneTeamMembersForTeamManager() throws {
        let user = subscribedTeamManager.user
        let urlSession = teamMembersURLSession(user: user, numberOfTeamMembers: 1)
        setupGlobals(session: urlSession)
        let conn = TestConnection(syncTeamMembersQueries(user: user))
        try Task.syncTeamMembersWithRecurly(userId: user.id).interpret(conn.lazy) { _ in }
        conn.assertDone()
        urlSession.assertDone()
    }
}
