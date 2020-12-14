//
//  Recurly.swift
//  Bits
//
//  Created by Chris Eidhof on 13.08.18.
//

import Foundation
import Promise
import Networking
import Base
import Database
import TinyNetworking

let recurly = Recurly()

struct Amount: Codable {
    enum CodingKeys: String, CodingKey {
        case usdCents = "USD"
    }
    var usdCents: Int

    func discounted(percent: Int) -> Amount {
        let cents = Int(Float(usdCents) * Float(1-Float(percent)/100))
        return Amount(usdCents: cents)
    }
}

extension Amount: ExpressibleByIntegerLiteral, Comparable {
    static func <(lhs: Amount, rhs: Amount) -> Bool {
        return lhs.usdCents < rhs.usdCents
    }
    
    init(integerLiteral value: Int) {
        usdCents = value
    }
}

func -(lhs: Amount, rhs: Amount) -> Amount {
    return Amount(usdCents: lhs.usdCents-rhs.usdCents)
}

struct Plan: Codable {
    enum IntervalUnit: String, Codable {
        case months
        case days
    }
    struct AddOn: Codable, RootElement {
        static let rootElementName: String = "add_on"
        var add_on_code: String
        var unit_amount_in_cents: Amount
    }
    var plan_code: String
    var name: String
    var description: String?
    var plan_interval_length: Int
    var plan_interval_unit: IntervalUnit
    var unit_amount_in_cents: Amount
    var total_billing_cycles: Int?
}

fileprivate extension Plan {
    var sortDuration: Int {
        switch self.plan_interval_unit {
        case .days: return plan_interval_length
        case .months: return plan_interval_length * 30
        }
    }
}

extension Plan {
    static func find(code: String) -> Plan? {
        return all.first { $0.plan_code == code }
    }
    static var monthly: Plan? {
        return all.first { $0.isMonthly && $0.isStandardPlan }
    }
    
    static var yearly: Plan? {
        return all.first { $0.isYearly && $0.isStandardPlan }
    }

    static var gifts: [Plan] {
        return all.filter { $0.isGiftPlan }.sorted { $0.sortDuration < $1.sortDuration } // TODO
    }

    var isStandardPlan: Bool {
        return !isGiftPlan && !isEnterprisePlan
    }
    
    var isEnterprisePlan: Bool {
        return plan_code.hasPrefix("enterprise")
    }
    
    var isGiftPlan: Bool {
        return plan_code.hasPrefix("gift")
    }
    
    var isMonthly: Bool {
        return plan_interval_unit == .months && plan_interval_length == 1
    }

    var isYearly: Bool {
        return plan_interval_unit == .months && plan_interval_length == 12
    }

    var teamMemberPrice: Amount {
        // todo think of a good way to load this from recurly
        return isMonthly ? 1000 : 10000
    }

    var teamMemberAddOn: Endpoint<AddOn> {
        return recurly.teamMemberAddOn(plan_code: plan_code)
    }
    
    func discountedPrice(basePrice: KeyPath<Plan, Amount>, coupon: Coupon?) -> Amount {
        let base = self[keyPath: basePrice]
        guard let c = coupon else { return base }
        guard c.applies_to_all_plans || c.plan_codes.contains(plan_code) else {
            return base
        }
        switch c.discount_type {
        case .dollars where c.discount_in_cents != nil:
            return max(0, base - c.discount_in_cents!)
        case .percent where c.discount_percent != nil :
            return max(0, base.discounted(percent: c.discount_percent!))
        case .freeTrial: return base // todo?
        default: return base
        }
    }
    
    func discountedTeamMemberPrice(coupon: Coupon?) -> Amount {
        return discountedPrice(basePrice: \.teamMemberPrice, coupon: coupon)
    }

    func discountedPrice(coupon: Coupon?) -> Amount {
        return discountedPrice(basePrice: \.unit_amount_in_cents, coupon: coupon)
    }
}

struct Subscription: Codable, Equatable {
    enum State: String, Codable {
        case active, canceled, future, expired
    }
    
    struct PlanInfo: Codable, Equatable {
        var plan_code: String
        var name: String
    }
    
    struct AddOn: Codable, Equatable {
        var add_on_code: String
        var unit_amount_in_cents: Int
        var quantity: Int
    }
    
    var state: State
    var uuid: String
    var activated_at: Date?
    var expires_at: Date?
    var current_period_ends_at: Date?
    var trial_ends_at: Date?
    var plan: PlanInfo
    var quantity: Int
    var unit_amount_in_cents: Int
    var tax_rate: Double?
    var subscription_add_ons: [AddOn]?
}

extension Date {
    func numberOfMonths(since: Date) -> UInt {
        let components = Calendar.current.dateComponents([.month], from: since, to: self)
        return UInt(components.month!) + 1
    }
}

extension Subscription {
    var activeMonths: UInt {
        guard let act = activated_at, let end = current_period_ends_at else { return 0 }
        return end.numberOfMonths(since: act)
    }

    func totalAtRenewal(addOn: Plan.AddOn, vatExempt: Bool) -> (total: Int, vat: Int) {
        let teamMemberPrice: Int
        if let a = subscription_add_ons?.first, a.add_on_code == addOn.add_on_code {
            teamMemberPrice = a.quantity * addOn.unit_amount_in_cents.usdCents
        } else {
            teamMemberPrice = 0
        }
        let beforeTax = unit_amount_in_cents * quantity + teamMemberPrice
        if let rate = tax_rate, !vatExempt {
            let vat = Int(Double(beforeTax) * rate)
            return (beforeTax + vat, vat)
        }
        return (beforeTax, 0)
    }

    // Returns nil if there aren't any upgrades.
    func upgrade(vatExempt: Bool) -> Upgrade? {
        if state == .active, let m = Plan.monthly, plan.plan_code == m.plan_code, let y = Plan.yearly {
            let teamMembers = subscription_add_ons?.first?.quantity ?? 0
            let totalWithoutVat = y.unit_amount_in_cents.usdCents + (teamMembers * y.teamMemberPrice.usdCents)
            var vat = 0
            if let rate = tax_rate, !vatExempt {
                vat = Int(Double(totalWithoutVat) * rate)
            }
            let total = totalWithoutVat + vat
            return Upgrade(plan: y, total_without_vat: totalWithoutVat, total_in_cents: total, vat_in_cents: vat, tax_rate: tax_rate, team_members: teamMembers, per_team_member_in_cents: y.teamMemberPrice.usdCents)
        } else {
            return nil
        }
    }

    struct Upgrade {
        let plan: Plan
        let total_without_vat: Int
        let total_in_cents: Int
        let vat_in_cents: Int
        let tax_rate: Double?
        let team_members: Int
        let per_team_member_in_cents: Int
    }
}

extension Sequence where Element == Subscription {
    var activeMonths: UInt {
        return map { $0.activeMonths }.reduce(0, +)
    }
}

struct Redemption: Codable {
    var uuid: String
    var single_use: Bool
    var total_discounted_in_cents: Int
    var currency: String
    var state: String
    var coupon_code: String
    var created_at: Date
    var updated_at: Date
}

struct Account: Codable {
    enum State: String, Codable {
        case active, closed, subscriber, non_subscriber, past_due
    }
//    var adjustments: URL
//    var account_balance: URL
//    var billing_info: URL?
//    var invoices: URL
//    var redemption: URL?
//    var subscriptions: URL
//    var transactions: URL
    var account_code: String
//    var state: State
//    var username: String?
//    var email: String
//    var cc_emails: String?
//    var first_name: String?
//    var last_name: String?
//    var company_name: String?
//    var vat_number: String?
//    var tax_exempt: Bool
//    // var address: object
//    var accept_language: String?
    var hosted_login_token: String
//    var created_at: Date
//    var updated_at: Date
//    var closed_at: Date?
//    var has_live_subscription: Bool
    var has_active_subscription: Bool
//    var has_future_subscription: Bool
    var has_canceled_subscription: Bool
//    var has_paused_subscription: String
//    var has_past_due_invoice: Bool
//    var preferred_locale: String?
}

struct BillingInfo: Codable {
    var first_name: String?
    var last_name: String?
    var company: String?
    var address1: String?
    var address2: String?
    var city: String?
    var state: String?
    var zip: String?
    var country: String?
    var phone: String?
    var vat_number: String?
    var ip_address: String
    var ip_address_country: String
    var card_type: String
    var year: Int
    var month: Int
    var first_six: String
    var last_four: String
    var updated_at: Date
}

extension BillingInfo {
    var vatExempt: Bool {
        return vat_number != nil && country != "DE"
    }
}

struct Invoice: Codable {
    enum State: String, Codable {
        case pending
        case paid
        case failed
        case past_due
        case open
        case closed
        case voided
        case processing
    }
    var invoice_number: Int
    var state: State
    var uuid: String
    var tax_in_cents: Int
    var total_in_cents: Int
    var currency: String
    var created_at: Date
}

extension Account {
    var subscriber: Bool {
        return has_active_subscription || has_canceled_subscription
    }
}

struct Webhook: Codable {
    var account: WebhookAccount
    var subscription: Subscription?
    struct Subscription: Codable, Equatable, Hashable {
        var plan: Plan
        var uuid: String
        var state: String
        var activated_at: Date?
    }
    struct Plan: Codable, Equatable, Hashable {
        var plan_code: String
        var name: String
    }
}

struct WebhookAccount: Codable {
    var account_code: UUID
}

enum TemporalUnit: String, Codable, Equatable {
    case day
    case week
    case month
    case year
    
    func prettyDuration(units: Int) -> String {
        switch self {
        case .day:
            return units == 1 ? "1 day" : "\(units) days"
        case .week:
            return units == 1 ? "1 week" : "\(units) weeks"
        case .month:
            return units == 1 ? "1 month" : "\(units) months"
        case .year:
            return units == 1 ? "1 year" : "\(units) years"
        }
    }
}

struct Coupon: Codable {
    enum DiscountType: String, Codable, Equatable {
        case percent
        case dollars
        case freeTrial = "free_trial"
    }
    enum DurationType: String, Codable, Equatable {
        case forever
        case single_use
        case temporal
    }
    enum CouponType: String, Codable, Equatable {
        case single_code
        case bulk
    }
    var id: Int
    var coupon_code: String
    var name: String
    var state: String
    var description: String
    var discount_type: DiscountType
    var discount_in_cents: Amount?
    var free_trial_amount: Int?
    var free_trial_unit: TemporalUnit?
    var discount_percent: Int?
    var invoice_description: String?
    var redeem_by_date: Date?
    var single_use: Bool
    var applies_for_months: Int?
    var max_redemptions: Int?
    var applies_to_all_plans: Bool
    var created_at: Date
    var updated_at: Date
    var deleted_at: Date?
    var duration: DurationType
    var temporal_unit: TemporalUnit?
    var temporal_amount: Int?
    var applies_to_non_plan_charges: Bool
    var redemption_resource: String
    var max_redemptions_per_account: Int?
    var coupon_type: CouponType
    var unique_code_template: String?
    var plan_codes: [String]
}

extension Coupon {
    var billingDescription: String {
        let prettyDuration: String
        switch duration {
        case .forever:
            prettyDuration = "forever"
        case .single_use:
            prettyDuration = "once"
        case .temporal:
            guard let u = temporal_unit, let a = temporal_amount else {
                prettyDuration = "unknown"
                log(error: "temporal coupon without amount or unit \(self)")

                break
                
            }
            prettyDuration = "for \(u.prettyDuration(units: a))"
        }

        if discount_type == .percent, let p = discount_percent {
            return "\(p)% off \(prettyDuration)"
        } else if discount_type == .dollars, let d = discount_in_cents {
            let am = dollarAmount(cents: d.usdCents)
            return "\(am) off \(prettyDuration)"
        } else if discount_type == .freeTrial, let a = free_trial_amount, let u = free_trial_unit {
            return "Free trial for \(u.prettyDuration(units: a))"
        } else {
            return description
        }
    }
    
    private var uniqueCodeRegex: NSRegularExpression? {
        guard let template = unique_code_template else { return nil }
        var pattern = ""
        var fixed = false
        for c in template {
            switch c {
            case "'":
                fixed.toggle()
            case "a"..."z", "A"..."Z", "0"..."9":
                if fixed {
                    pattern.append(c)
                } else {
                    switch c {
                    case "x", "X": pattern.append("[a-zA-Z]")
                    case "9": pattern.append("\\d")
                    default: break
                    }
                }
            case "-" where fixed, "_" where fixed, "+" where fixed:
                pattern.append("\\\(c)")
            case "*" where !fixed:
                pattern.append("[a-zA-Z0-9]")
            default:
                break
            }
        }
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
    
    func matches(_ code: String) -> Bool {
        switch coupon_type {
        case .single_code:
            return coupon_code == code
        case .bulk:
            let range = NSRange(code.startIndex..<code.endIndex, in: code)
            return uniqueCodeRegex?.matches(in: code, options: [], range: range).first != nil
        }
    }
}

struct CreateSubscription: Codable, RootElement {
    static let rootElementName: String = "subscription"
    struct CreateBillingInfo: Codable {
        var token_id: String
        var three_d_secure_action_result_token_id: String? = nil
    }
    struct CreateAccount: Codable {
        var account_code: UUID // Recurly allows more things than this, but we'll just go for the UUID
        var email: String
        var billing_info: CreateBillingInfo
    }
    var plan_code: String
    var currency: String = "USD"
    var coupon_code: String? = nil
    var starts_at: Date? = nil
    var account: CreateAccount
}

fileprivate let teamMemberAddOnCode = "team_members"

struct UpdateSubscription: Codable, RootElement {
    static let rootElementName = "subscription"
    struct AddOn: Codable, RootElement {
        static let rootElementName: String = "subscription_add_on"
        var add_on_code = teamMemberAddOnCode
        var quantity: Int
    }
    var timeframe: String = "now"
    var plan_code: String?
    var subscription_add_ons: [AddOn]?

    init(timeframe: String = "now", plan_code: String? = nil, subscription_add_ons: [AddOn]? = nil) {
        self.timeframe = timeframe
        self.plan_code = plan_code
        self.subscription_add_ons = subscription_add_ons
    }
}

struct RecurlyTransactionError: Decodable {
    var error_code: String
    var customer_message: String
    var three_d_secure_action_token_id: String?
}

struct RecurlyErrorField: Decodable {
    let field: String?
    let symbol: String?
    let message: String
}

struct RecurlyError: Decodable, Error {
    var transaction_error: RecurlyTransactionError
    var error: RecurlyErrorField
    
    var isInvalidEmail: Bool {
        return error.field == "subscription.account.email" && error.message == "invalid_email"
    }
    
    var threeDActionToken: String? {
        guard transaction_error.error_code == "three_d_secure_action_required", let token = transaction_error.three_d_secure_action_token_id else { return nil }
        return token
    }
}

enum RecurlyResult<A> {
    case success(A)
    case error(RecurlyError)
}

struct RecurlyVoid: Decodable {
}

enum RecurlyOptional<A>: Decodable where A: Decodable {
    case some(A)
    case none
    
    init(from decoder: Decoder) throws {
        do {
            let value = try A(from: decoder)
            self = .some(value)
        } catch {
            self = .none
        }
    }
}

extension RecurlyResult: Decodable where A: Decodable {
    init(from decoder: Decoder) throws {
        do {
            let value = try A(from: decoder)
            self = .success(value)
        } catch {
            let value = try RecurlyError(from: decoder)
            self = .error(value)
        }
    }
}

extension Row where Element == UserData {
    var account: Endpoint<Account> {
        return recurly.account(with: id)
    }
    
    var invoices: Endpoint<[Invoice]> {
        return recurly.listInvoices(accountId: self.id.uuidString)
    }
    
    var subscriptions: Endpoint<[Subscription]> {
        return recurly.listSubscriptions(accountId: self.id.uuidString)
    }
    
    var redemptions: Endpoint<[Redemption]> {
        return recurly.redemptions(accountId: id.uuidString)
    }
    
    var currentSubscription: Endpoint<Subscription?> {
        return subscriptions.map { $0.first { $0.state == .active || $0.state == .canceled } }
    }
    
    var billingInfo: Endpoint<BillingInfo?> {
        return recurly.billingInfo(accountId: id).map {
            guard case let .some(x) = $0 else { return nil }
            return x
        }
    }
    
    func updateBillingInfo(token: String, threeDResultToken: String? = nil) -> Endpoint<RecurlyResult<BillingInfo>> {
        return recurly.updatePaymentMethod(for: id, token: token, threeDResultToken: threeDResultToken)
    }
    
    func updateCurrentSubscription(numberOfTeamMembers: Int) -> CombinedEndpoint<Subscription> {
        return currentSubscription.c.flatMap { sub in
            guard let s = sub else { return nil }
            return recurly.updateSubscription(s, numberOfTeamMembers: numberOfTeamMembers).c
        }
    }
}

struct Recurly {
    let apiKey = env.recurlyApiKey
    let host = "\(env.recurlySubdomain).recurly.com"
    let base: URL
    var headers: [String:String] {
        return [
            "X-Api-Version": "2.21",
            "Content-Type": "application/xml; charset=utf-8",
            "Authorization": "Basic \(apiKey.base64Encoded)"
        ]
    }
    
    init() {
        self.base = URL(string: "https://\(host)/v2")!
    }
    
    var plans: Endpoint<[Plan]> {
        return Endpoint(xml: .get, url: base.appendingPathComponent("plans"), headers: headers)
    }
    
    var listAccounts: Endpoint<[Account]> {
        return Endpoint(xml: .get, url: base.appendingPathComponent("accounts"), headers: headers)
    }
    
    func billingInfo(accountId id: UUID) -> Endpoint<RecurlyOptional<BillingInfo>> {
        return Endpoint(xml: .get, url: base.appendingPathComponent("accounts/\(id.uuidString)/billing_info"), headers: headers)
    }
    
    func teamMemberAddOn(plan_code: String) -> Endpoint<Plan.AddOn> {
        return Endpoint(xml: .get, url: base.appendingPathComponent("plans/\(plan_code)/add_ons/\(teamMemberAddOnCode)"), headers: headers)
    }
    
    func updatePaymentMethod(for accountId: UUID, token: String, threeDResultToken: String?) -> Endpoint<RecurlyResult<BillingInfo>> {
        struct UpdateData: Codable, RootElement {
            var token_id: String
            var three_d_secure_action_result_token_id: String?
            static let rootElementName = "billing_info"
        }
        return Endpoint(xml: .put, url: base.appendingPathComponent("accounts/\(accountId.uuidString)/billing_info"), value: UpdateData(token_id: token, three_d_secure_action_result_token_id: threeDResultToken), headers: headers)
    }

    func account(with id: UUID) -> Endpoint<Account> {
        return Endpoint(xml: .get, url: base.appendingPathComponent("accounts/\(id.uuidString)"), headers: headers)
    }

    func listSubscriptions(accountId: String) -> Endpoint<[Subscription]> {
        return Endpoint(xml: .get, url: base.appendingPathComponent("accounts/\(accountId)/subscriptions"), headers: headers, query: ["per_page": "200"])
    }
    
    func listInvoices(accountId: String) -> Endpoint<[Invoice]> {
        return Endpoint(xml: .get, url: base.appendingPathComponent("accounts/\(accountId)/invoices"), headers: headers, query: ["per_page": "200"])
    }
    
    func redemptions(accountId: String) -> Endpoint<[Redemption]> {
        return Endpoint(xml: .get, url: base.appendingPathComponent("accounts/\(accountId)/redemptions"), headers: headers, query: ["per_page": "200"])
    }

    func createSubscription(_ x: CreateSubscription) -> Endpoint<RecurlyResult<Subscription>> {
        let url = base.appendingPathComponent("subscriptions")
        return Endpoint(xml: .post, url: url, value: x, headers: headers)
    }
    
    func cancel(_ subscription: Subscription) -> Endpoint<RecurlyResult<RecurlyVoid>> {
        let url = base.appendingPathComponent("subscriptions/\(subscription.uuid)/cancel")
        return Endpoint(xml: .put, url: url, headers: headers)
    }
    
    enum Refund: String {
        case full
        case partial
        case none
    }
    
    func terminate(_ subscription: Subscription, refund: Refund) -> Endpoint<RecurlyResult<RecurlyVoid>> {
        let url = base.appendingPathComponent("subscriptions/\(subscription.uuid)/terminate")
        return Endpoint(xml: .put, url: url, headers: headers, query: ["refund": refund.rawValue])
    }
    
    func reactivate(_ subscription: Subscription) -> Endpoint<RecurlyResult<RecurlyVoid>> {
        let url = base.appendingPathComponent("subscriptions/\(subscription.uuid)/reactivate")
        return Endpoint(xml: .put, url: url, headers: headers)
    }
    
    func updateSubscription(_ subscription: Subscription, plan_code: String? = nil, numberOfTeamMembers: Int) -> Endpoint<Subscription> {
        let addons: [UpdateSubscription.AddOn]
        addons = numberOfTeamMembers > 0 ? [UpdateSubscription.AddOn(add_on_code: teamMemberAddOnCode, quantity: numberOfTeamMembers)] : []
        let url = base.appendingPathComponent("subscriptions/\(subscription.uuid)")
        return Endpoint(xml: .put, url: url, value: UpdateSubscription(timeframe: "now", plan_code: plan_code, subscription_add_ons: addons), headers: headers, query: [:])
    }
    
    func updateAccount(accountCode: UUID, email: String) -> Endpoint<Account> {
        struct UpdateAccount: Codable, RootElement {
            static let rootElementName = "account"
            var email: String
        }
        let url = base.appendingPathComponent("accounts/\(accountCode.uuidString)")
        return Endpoint(xml: .put, url: url, value: UpdateAccount(email: email), headers: headers)
    }

    func coupon(code: String) -> Endpoint<Coupon> {
        let url = base.appendingPathComponent("coupons/\(code)")
        return Endpoint(xml: .get, url: url, headers: headers)
    }

    func coupons() -> Endpoint<[Coupon]> {
        let url = base.appendingPathComponent("coupons")
        return Endpoint(xml: .get, url: url, headers: headers)
    }

    func subscriptionStatus(for accountId: UUID) -> Promise<(subscriber: Bool, canceled: Bool, downloadCredits: UInt)?> {
        return Promise { cb in
            globals.urlSession.load(self.account(with: accountId)) { result in
                guard let acc = result else { cb(nil); return }
                globals.urlSession.load(recurly.listSubscriptions(accountId: acc.account_code)) { result in
                    let subs = try? result.get()
                    let hasActiveSubscription = subs?.contains(where: { $0.state == .active }) ?? false
                    cb((acc.subscriber, canceled: !hasActiveSubscription, (subs?.activeMonths ?? 0) * 4))
                }
            }
        }
    }
    
    func pdfURL(invoice: Invoice, hostedLoginToken: String) -> URL {
        return URL(string: "https://\(host)/account/invoices/\(invoice.invoice_number).pdf?ht=\(hostedLoginToken)")!
    }

}

fileprivate extension Endpoint where A: Decodable {
    init(xml method: Method, url: URL, headers: [String:String], query: [String:String] = [:]) {
        self.init(method, url: url, accept: .xml, headers: headers, expectedStatusCode: { $0 >= 200 && $0 < 500 }, query: query, parse: { d, _ in parseRecurlyResponse(url, d) })
    }

    init<B: Encodable & RootElement>(xml method: Method, url: URL, value: B, headers: [String:String], query: [String:String] = [:]) {
        let data = try! encodeXML(value).data(using: .utf8)!
        self.init(method, url: url, accept: .xml, body: data, headers: headers, expectedStatusCode: { $0 >= 200 && $0 < 500 }, query: query, parse: { d, _ in parseRecurlyResponse(url, d) })
    }
}

private func parseRecurlyResponse<T: Decodable>(_ url: URL, _ d: Data?) -> Result<T, Error> {
    return Result {
        guard let data = d else { throw NoDataError() }
        do {
            return try decodeXML(from: data)
        } catch {
            log(error: "Decoding error \(url): \(error), \(error.localizedDescription), \(String(data: data, encoding: .utf8)!)")
            throw error
        }
    }
}
