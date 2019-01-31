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

let noConnection = Lazy<ConnectionProtocol>({ fatalError() }, cleanup: { _ in () })

let nonSubscribedUser = Session(sessionId: UUID(), user: Row(id: UUID(), data: UserData(email: "test@example.com", avatarURL: "", name: "Tester")), teamMember: nil, teamManager: nil, gifter: nil)
let subscribedUser = Session(sessionId: UUID(), user: Row(id: UUID(), data: UserData(email: "test@example.com", avatarURL: "", name: "Tester", subscriber: true)), teamMember: nil, teamManager: nil, gifter: nil)
let subscribedTeamManager = Session(sessionId: UUID(), user: Row(id: UUID(), data: UserData(email: "test@example.com", avatarURL: "", name: "Tester", role: .teamManager, subscriber: true)), teamMember: nil, teamManager: nil, gifter: nil)
let activeSubscription = Subscription(state: .active, uuid: UUID().uuidString, activated_at: Date().addingTimeInterval(-10000), expires_at: nil, current_period_ends_at: nil, trial_ends_at: nil, plan: .init(plan_code: "monthly", name: "Subscription"), quantity: 1, unit_amount_in_cents: 1000, tax_rate: nil, subscription_add_ons: nil)
