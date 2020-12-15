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

fileprivate let createSubXML = """
<?xml version="1.0" encoding="UTF-8"?>
<subscription>
<plan_code>monthly-test</plan_code>
<currency>USD</currency>
<account>
<account_code>241A52B6-CE23-4B6A-90B7-52710F3E6312</account_code>
<email>mail@floriankugler.com</email>
<billing_info>
<token_id>O_zV7-8FNW6gYR0tXqrxjA</token_id>
</billing_info>
</account>
</subscription>
"""

fileprivate let planSample = """
<?xml version="1.0" encoding="UTF-8"?>
<plans type="array">
<plan href="https://objcio-staging.recurly.com/v2/plans/enterprise_yearly_atlassian">
<add_ons href="https://objcio-staging.recurly.com/v2/plans/enterprise_yearly_atlassian/add_ons"/>
<plan_code>enterprise_yearly_atlassian</plan_code>
<name>Enterprise Plan</name>
<description>Atlassian Enterprise Plan</description>
<success_url nil="nil"></success_url>
<cancel_url nil="nil"></cancel_url>
<display_donation_amounts type="boolean">false</display_donation_amounts>
<display_quantity type="boolean">false</display_quantity>
<display_phone_number type="boolean">false</display_phone_number>
<bypass_hosted_confirmation type="boolean">false</bypass_hosted_confirmation>
<unit_name>unit</unit_name>
<payment_page_tos_link nil="nil"></payment_page_tos_link>
<plan_interval_length type="integer">12</plan_interval_length>
<plan_interval_unit>months</plan_interval_unit>
<trial_interval_length type="integer">0</trial_interval_length>
<trial_interval_unit>days</trial_interval_unit>
<total_billing_cycles nil="nil"></total_billing_cycles>
<accounting_code></accounting_code>
<setup_fee_accounting_code></setup_fee_accounting_code>
<created_at type="datetime">2019-03-25T08:08:07Z</created_at>
<updated_at type="datetime">2019-03-25T08:08:07Z</updated_at>
<revenue_schedule_type>evenly</revenue_schedule_type>
<setup_fee_revenue_schedule_type>evenly</setup_fee_revenue_schedule_type>
<trial_requires_billing_info type="boolean">true</trial_requires_billing_info>
<tax_exempt type="boolean">false</tax_exempt>
<tax_code>digital</tax_code>
<unit_amount_in_cents>
<USD type="integer">500000</USD>
</unit_amount_in_cents>
<setup_fee_in_cents>
<USD type="integer">0</USD>
</setup_fee_in_cents>
</plan>
<plan href="https://objcio-staging.recurly.com/v2/plans/gift_three_months">
<add_ons href="https://objcio-staging.recurly.com/v2/plans/gift_three_months/add_ons"/>
<plan_code>gift_three_months</plan_code>
<name>Gift Three Months</name>
<description>Three Month Gift Plan</description>
<success_url nil="nil"></success_url>
<cancel_url nil="nil"></cancel_url>
<display_donation_amounts type="boolean">false</display_donation_amounts>
<display_quantity type="boolean">false</display_quantity>
<display_phone_number type="boolean">false</display_phone_number>
<bypass_hosted_confirmation type="boolean">false</bypass_hosted_confirmation>
<unit_name>unit</unit_name>
<payment_page_tos_link nil="nil"></payment_page_tos_link>
<plan_interval_length type="integer">3</plan_interval_length>
<plan_interval_unit>months</plan_interval_unit>
<trial_interval_length type="integer">0</trial_interval_length>
<trial_interval_unit>days</trial_interval_unit>
<total_billing_cycles nil="nil"></total_billing_cycles>
<accounting_code nil="nil"></accounting_code>
<setup_fee_accounting_code nil="nil"></setup_fee_accounting_code>
<created_at type="datetime">2018-12-07T15:50:39Z</created_at>
<updated_at type="datetime">2018-12-07T15:50:39Z</updated_at>
<revenue_schedule_type>evenly</revenue_schedule_type>
<setup_fee_revenue_schedule_type>evenly</setup_fee_revenue_schedule_type>
<trial_requires_billing_info type="boolean">true</trial_requires_billing_info>
<tax_exempt type="boolean">false</tax_exempt>
<tax_code nil="nil"></tax_code>
<unit_amount_in_cents>
<USD type="integer">4500</USD>
</unit_amount_in_cents>
<setup_fee_in_cents>
<USD type="integer">0</USD>
</setup_fee_in_cents>
</plan>
<plan href="https://objcio-staging.recurly.com/v2/plans/gift_six_months">
<add_ons href="https://objcio-staging.recurly.com/v2/plans/gift_six_months/add_ons"/>
<plan_code>gift_six_months</plan_code>
<name>Gift Six Months</name>
<description>Six Month Gift</description>
<success_url nil="nil"></success_url>
<cancel_url nil="nil"></cancel_url>
<display_donation_amounts type="boolean">false</display_donation_amounts>
<display_quantity type="boolean">false</display_quantity>
<display_phone_number type="boolean">false</display_phone_number>
<bypass_hosted_confirmation type="boolean">false</bypass_hosted_confirmation>
<unit_name>unit</unit_name>
<payment_page_tos_link nil="nil"></payment_page_tos_link>
<plan_interval_length type="integer">6</plan_interval_length>
<plan_interval_unit>months</plan_interval_unit>
<trial_interval_length type="integer">0</trial_interval_length>
<trial_interval_unit>days</trial_interval_unit>
<total_billing_cycles type="integer">1</total_billing_cycles>
<accounting_code nil="nil"></accounting_code>
<setup_fee_accounting_code nil="nil"></setup_fee_accounting_code>
<created_at type="datetime">2018-12-07T15:50:05Z</created_at>
<updated_at type="datetime">2018-12-07T15:50:05Z</updated_at>
<revenue_schedule_type>evenly</revenue_schedule_type>
<setup_fee_revenue_schedule_type>evenly</setup_fee_revenue_schedule_type>
<trial_requires_billing_info type="boolean">true</trial_requires_billing_info>
<tax_exempt type="boolean">false</tax_exempt>
<tax_code>digital</tax_code>
<unit_amount_in_cents>
<USD type="integer">8000</USD>
</unit_amount_in_cents>
<setup_fee_in_cents>
<USD type="integer">0</USD>
</setup_fee_in_cents>
</plan>
<plan href="https://objcio-staging.recurly.com/v2/plans/gift_one_year">
<add_ons href="https://objcio-staging.recurly.com/v2/plans/gift_one_year/add_ons"/>
<plan_code>gift_one_year</plan_code>
<name>One Year Gift</name>
<description>One Year Gift Plan</description>
<success_url nil="nil"></success_url>
<cancel_url nil="nil"></cancel_url>
<display_donation_amounts type="boolean">false</display_donation_amounts>
<display_quantity type="boolean">false</display_quantity>
<display_phone_number type="boolean">false</display_phone_number>
<bypass_hosted_confirmation type="boolean">false</bypass_hosted_confirmation>
<unit_name>unit</unit_name>
<payment_page_tos_link nil="nil"></payment_page_tos_link>
<plan_interval_length type="integer">12</plan_interval_length>
<plan_interval_unit>months</plan_interval_unit>
<trial_interval_length type="integer">0</trial_interval_length>
<trial_interval_unit>days</trial_interval_unit>
<total_billing_cycles type="integer">1</total_billing_cycles>
<accounting_code nil="nil"></accounting_code>
<setup_fee_accounting_code nil="nil"></setup_fee_accounting_code>
<created_at type="datetime">2018-12-07T15:49:21Z</created_at>
<updated_at type="datetime">2018-12-07T15:49:21Z</updated_at>
<revenue_schedule_type>evenly</revenue_schedule_type>
<setup_fee_revenue_schedule_type>evenly</setup_fee_revenue_schedule_type>
<trial_requires_billing_info type="boolean">true</trial_requires_billing_info>
<tax_exempt type="boolean">false</tax_exempt>
<tax_code>digital</tax_code>
<unit_amount_in_cents>
<USD type="integer">15000</USD>
</unit_amount_in_cents>
<setup_fee_in_cents>
<USD type="integer">0</USD>
</setup_fee_in_cents>
</plan>
<plan href="https://objcio-staging.recurly.com/v2/plans/monthly-test">
<add_ons href="https://objcio-staging.recurly.com/v2/plans/monthly-test/add_ons"/>
<plan_code>monthly-test</plan_code>
<name>Test Monthly</name>
<description>The monthly plan</description>
<success_url></success_url>
<cancel_url nil="nil"></cancel_url>
<display_donation_amounts type="boolean">false</display_donation_amounts>
<display_quantity type="boolean">false</display_quantity>
<display_phone_number type="boolean">false</display_phone_number>
<bypass_hosted_confirmation type="boolean">false</bypass_hosted_confirmation>
<unit_name>unit</unit_name>
<payment_page_tos_link nil="nil"></payment_page_tos_link>
<plan_interval_length type="integer">1</plan_interval_length>
<plan_interval_unit>months</plan_interval_unit>
<trial_interval_length type="integer">0</trial_interval_length>
<trial_interval_unit>days</trial_interval_unit>
<total_billing_cycles nil="nil"></total_billing_cycles>
<accounting_code nil="nil"></accounting_code>
<setup_fee_accounting_code nil="nil"></setup_fee_accounting_code>
<created_at type="datetime">2016-12-05T13:32:22Z</created_at>
<updated_at type="datetime">2016-12-05T13:32:22Z</updated_at>
<revenue_schedule_type>evenly</revenue_schedule_type>
<setup_fee_revenue_schedule_type>evenly</setup_fee_revenue_schedule_type>
<trial_requires_billing_info type="boolean">true</trial_requires_billing_info>
<tax_exempt type="boolean">false</tax_exempt>
<tax_code>digital</tax_code>
<unit_amount_in_cents>
<USD type="integer">1900</USD>
</unit_amount_in_cents>
<setup_fee_in_cents>
<USD type="integer">0</USD>
</setup_fee_in_cents>
</plan>
<plan href="https://objcio-staging.recurly.com/v2/plans/yearly-test">
<add_ons href="https://objcio-staging.recurly.com/v2/plans/yearly-test/add_ons"/>
<plan_code>yearly-test</plan_code>
<name>Yearly Test</name>
<description>Yearly test plan</description>
<success_url></success_url>
<cancel_url nil="nil"></cancel_url>
<display_donation_amounts type="boolean">false</display_donation_amounts>
<display_quantity type="boolean">false</display_quantity>
<display_phone_number type="boolean">false</display_phone_number>
<bypass_hosted_confirmation type="boolean">false</bypass_hosted_confirmation>
<unit_name>unit</unit_name>
<payment_page_tos_link nil="nil"></payment_page_tos_link>
<plan_interval_length type="integer">12</plan_interval_length>
<plan_interval_unit>months</plan_interval_unit>
<trial_interval_length type="integer">0</trial_interval_length>
<trial_interval_unit>days</trial_interval_unit>
<total_billing_cycles nil="nil"></total_billing_cycles>
<accounting_code nil="nil"></accounting_code>
<setup_fee_accounting_code nil="nil"></setup_fee_accounting_code>
<created_at type="datetime">2016-12-05T13:26:57Z</created_at>
<updated_at type="datetime">2016-12-05T13:26:57Z</updated_at>
<revenue_schedule_type>evenly</revenue_schedule_type>
<setup_fee_revenue_schedule_type>evenly</setup_fee_revenue_schedule_type>
<trial_requires_billing_info type="boolean">true</trial_requires_billing_info>
<tax_exempt type="boolean">false</tax_exempt>
<tax_code>digital</tax_code>
<unit_amount_in_cents>
<USD type="integer">9000</USD>
</unit_amount_in_cents>
<setup_fee_in_cents>
<USD type="integer">0</USD>
</setup_fee_in_cents>
</plan>
<plan href="https://objcio-staging.recurly.com/v2/plans/test">
<add_ons href="https://objcio-staging.recurly.com/v2/plans/test/add_ons"/>
<plan_code>test</plan_code>
<name>Test Daily</name>
<description nil="nil"></description>
<success_url></success_url>
<cancel_url nil="nil"></cancel_url>
<display_donation_amounts type="boolean">false</display_donation_amounts>
<display_quantity type="boolean">false</display_quantity>
<display_phone_number type="boolean">false</display_phone_number>
<bypass_hosted_confirmation type="boolean">false</bypass_hosted_confirmation>
<unit_name>unit</unit_name>
<payment_page_tos_link nil="nil"></payment_page_tos_link>
<plan_interval_length type="integer">1</plan_interval_length>
<plan_interval_unit>days</plan_interval_unit>
<trial_interval_length type="integer">0</trial_interval_length>
<trial_interval_unit>days</trial_interval_unit>
<total_billing_cycles nil="nil"></total_billing_cycles>
<accounting_code nil="nil"></accounting_code>
<setup_fee_accounting_code nil="nil"></setup_fee_accounting_code>
<created_at type="datetime">2016-06-10T10:45:43Z</created_at>
<updated_at type="datetime">2016-06-10T12:49:43Z</updated_at>
<revenue_schedule_type>evenly</revenue_schedule_type>
<setup_fee_revenue_schedule_type>evenly</setup_fee_revenue_schedule_type>
<trial_requires_billing_info type="boolean">true</trial_requires_billing_info>
<tax_exempt type="boolean">false</tax_exempt>
<tax_code>digital</tax_code>
<unit_amount_in_cents>
<USD type="integer">900</USD>
</unit_amount_in_cents>
<setup_fee_in_cents>
<USD type="integer">0</USD>
</setup_fee_in_cents>
</plan>
</plans>
"""

fileprivate let subscriptionsXML = """
<subscriptions type="array">
<subscription href="https://objcio-staging.recurly.com/v2/subscriptions/4d545421eac3baf943e1844addb27bad">
<account href="https://objcio-staging.recurly.com/v2/accounts/1CB0B0B5-8D65-46CC-9EF9-D0F015C1B5CF"/>
<invoice href="https://objcio-staging.recurly.com/v2/invoices/3414"/>
<plan href="https://objcio-staging.recurly.com/v2/plans/monthly-test">
<plan_code>monthly-test</plan_code>
<name>Test Monthly</name>
</plan>
<revenue_schedule_type>evenly</revenue_schedule_type>
<uuid>4d545421eac3baf943e1844addb27bad</uuid>
<state>active</state>
<unit_amount_in_cents type="integer">1900</unit_amount_in_cents>
<currency>USD</currency>
<quantity type="integer">1</quantity>
<activated_at type="datetime">2019-07-12T09:34:41Z</activated_at>
<canceled_at nil="nil"></canceled_at>
<expires_at nil="nil"></expires_at>
<updated_at type="datetime">2019-07-12T09:34:42Z</updated_at>
<total_billing_cycles nil="nil"></total_billing_cycles>
<remaining_billing_cycles nil="nil"></remaining_billing_cycles>
<current_period_started_at type="datetime">2019-07-12T09:34:41Z</current_period_started_at>
<current_period_ends_at type="datetime">2019-08-12T09:34:41Z</current_period_ends_at>
<trial_started_at nil="nil"></trial_started_at>
<trial_ends_at nil="nil"></trial_ends_at>
<terms_and_conditions nil="nil"></terms_and_conditions>
<customer_notes nil="nil"></customer_notes>
<started_with_gift type="boolean">false</started_with_gift>
<converted_at nil="nil"></converted_at>
<imported_trial type="boolean">false</imported_trial>
<paused_at nil="nil"></paused_at>
<remaining_pause_cycles nil="nil"></remaining_pause_cycles>
<no_billing_info_reason></no_billing_info_reason>
<tax_in_cents type="integer">361</tax_in_cents>
<tax_type>vat</tax_type>
<tax_region>DE</tax_region>
<tax_rate type="float">0.19</tax_rate>
<po_number nil="nil"></po_number>
<net_terms type="integer">0</net_terms>
<collection_method>automatic</collection_method>
<subscription_add_ons type="array">
</subscription_add_ons>
<custom_fields type="array">
</custom_fields>
<a name="cancel" href="https://objcio-staging.recurly.com/v2/subscriptions/4d545421eac3baf943e1844addb27bad/cancel" method="put"/>
<a name="terminate" href="https://objcio-staging.recurly.com/v2/subscriptions/4d545421eac3baf943e1844addb27bad/terminate" method="put"/>
<a name="postpone" href="https://objcio-staging.recurly.com/v2/subscriptions/4d545421eac3baf943e1844addb27bad/postpone" method="put"/>
<a name="notes" href="https://objcio-staging.recurly.com/v2/subscriptions/4d545421eac3baf943e1844addb27bad/notes" method="put"/>
</subscription>
</subscriptions>
"""

class RecurlyTests: XCTestCase {
    func testNewSubscriptionNotification() throws {
        let webhook: Webhook = try decodeXML(from: activateSubscription.data(using: .utf8)!)
        let expectedPlan = Webhook.Plan(plan_code: "gift_three_months", name: "Gift Three Months")
        XCTAssertEqual(webhook.subscription?.plan, expectedPlan)
    }
    
    func testCreateSubscriptionXML() throws {
        let x = CreateSubscription(plan_code: "monthly-test", currency: "USD", coupon_code: nil, starts_at: nil, account: CreateSubscription.CreateAccount(account_code: UUID(uuidString: "241A52B6-CE23-4B6A-90B7-52710F3E6312")!, email: "mail@floriankugler.com", billing_info: CreateSubscription.CreateBillingInfo(token_id: "O_zV7-8FNW6gYR0tXqrxjA")))
        XCTAssertEqual(try encodeXML(x), createSubXML)
    }
    
    func testPlan() throws {
        let _: [Plan] = try decodeXML(from: planSample.data(using: .utf8)!)
        XCTAssertTrue(true)
    }
    
    func testSubscriptions() throws {
        let sub = Subscription(state: .active, uuid: "4d545421eac3baf943e1844addb27bad", activated_at: DateFormatter.iso8601WithTimeZone.date(from: "2019-07-12T09:34:41Z"), expires_at: nil, current_period_ends_at: DateFormatter.iso8601WithTimeZone.date(from: "2019-08-12T09:34:41Z"), trial_ends_at: nil, plan: Subscription.PlanInfo(plan_code: "monthly-test", name: "Test Monthly"), quantity: 1, unit_amount_in_cents: 1900, tax_rate: 0.19, subscription_add_ons: [])
        XCTAssertEqual([sub], try decodeXML(from: subscriptionsXML.data(using: .utf8)!))
    }
}
