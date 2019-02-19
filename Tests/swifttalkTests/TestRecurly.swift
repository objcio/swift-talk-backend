//
//  TestRecurly.swift
//  Base
//
//  Created by Chris Eidhof on 19.02.19.
//

import Foundation
import XCTest
@testable import SwiftTalkServerLib

let activateSubscription = """
<?xml version="1.0" encoding="UTF-8"?>
<new_subscription_notification>
<account>
<account_code>18a6b9d7-7e0d-4e77-aef9-61bbdab14229</account_code>
<username nil="true"/>
<email>chris@eidhof.nl</email>
<first_name nil="true"/>
<last_name nil="true"/>
<company_name nil="true"/>
<phone nil="true"/>
</account>
<subscription>
<plan>
<plan_code>gift_three_months</plan_code>
<name>Gift Three Months</name>
</plan>
<uuid>4907581b76bd87fb2fdfdd4c75981d67</uuid>
<state>active</state>
<quantity type="integer">1</quantity>
<total_amount_in_cents type="integer">5355</total_amount_in_cents>
<subscription_add_ons type="array"/>
<activated_at type="datetime">2018-12-07T19:01:10Z</activated_at>
<canceled_at type="datetime" nil="true"></canceled_at>
<expires_at type="datetime" nil="true"></expires_at>
<current_period_started_at type="datetime">2018-12-07T19:01:10Z</current_period_started_at>
<current_period_ends_at type="datetime">2019-06-07T19:01:10Z</current_period_ends_at>
<trial_started_at type="datetime" nil="true"></trial_started_at>
<trial_ends_at type="datetime" nil="true"></trial_ends_at>
<paused_at type="datetime" nil="true"></paused_at>
<resume_at type="datetime" nil="true"></resume_at>
<remaining_pause_cycles nil="true"/>
</subscription>
</new_subscription_notification>
"""


class RecurlyTests: XCTestCase {
    func testNewSubscriptionNotification() throws {
        let webhook: Webhook = try decodeXML(from: activateSubscription.data(using: .utf8)!)
        let expectedPlan = Webhook.Plan(plan_code: "gift_three_months", name: "Gift Three Months")
        XCTAssertEqual(webhook.subscription?.plan, expectedPlan)
    }
}
