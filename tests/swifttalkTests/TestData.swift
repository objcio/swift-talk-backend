//
//  TestData.swift
//  SwiftTalkTests
//
//  Created by Chris Eidhof on 18.12.18.
//

import Foundation
@testable import SwiftTalkServerLib
import PostgreSQL

let testCSRF = CSRFToken(UUID())

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]


let plans = [
    Plan(plan_code: "monthly_plan", name: "Monthly Plan", description: nil, plan_interval_length: 1, plan_interval_unit: .months, unit_amount_in_cents: 100, total_billing_cycles: nil),
    Plan(plan_code: "yearly_plan", name: "Yearly Plan", description: nil, plan_interval_length: 12, plan_interval_unit: .months, unit_amount_in_cents: 1200, total_billing_cycles: nil)
]

let noConnection: Lazy<Connection> = Lazy<Connection>({ fatalError() }, cleanup: { _ in () })

let nonSubscribedUser = Session(sessionId: UUID(), user: Row(id: UUID(), data: UserData(email: "test@example.com", avatarURL: "", name: "Tester")), masterTeamUser: nil, gifter: nil)
let subscribedUser = Session(sessionId: UUID(), user: Row(id: UUID(), data: UserData(email: "test@example.com", avatarURL: "", name: "Tester", subscriber: true)), masterTeamUser: nil, gifter: nil)

