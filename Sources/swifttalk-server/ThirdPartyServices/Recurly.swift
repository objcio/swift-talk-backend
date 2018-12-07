//
//  Recurly.swift
//  Bits
//
//  Created by Chris Eidhof on 13.08.18.
//

import Foundation


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
    static var gifts: [Plan] {
        return all.filter { $0.plan_code.hasPrefix("gift") }.sorted { $0.sortDuration < $1.sortDuration } // TODO
    }
    static var monthly: Plan? {
        return all.first(where: { $0.plan_interval_unit == .months && $0.plan_interval_length == 1 })
    }
    static var yearly: Plan? {
        return all.first(where: { $0.plan_interval_unit == .months && $0.plan_interval_length == 12 })
    }
    
    var teamMemberPrice: Int? {
        // todo think of a good way to load this from recurly
        if plan_interval_unit == .months && plan_interval_length == 1 {
            return 1000
        } else if plan_interval_unit == .months && plan_interval_length == 12 {
            return 15000
        } else {
            return nil
        }
    }
    
    var teamMemberAddOn: RemoteEndpoint<AddOn> {
        return recurly.teamMemberAddOn(plan_code: plan_code)
    }

    func discountedPrice(coupon: Coupon?) -> Amount {
        let base = unit_amount_in_cents
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
}

struct Subscription: Codable {
    enum State: String, Codable {
        case active, canceled, future, expired
    }
    
    struct PlanInfo: Codable {
        var plan_code: String
        var name: String
    }
    
    struct AddOn: Codable {
        var add_on_code: String
        var unit_amount_in_cents: Int
        var quantity: Int
    }
    
    var state: State
    var uuid: String
    var activated_at: Date?
    var expires_at: Date?
    var current_period_ends_at: Date?
    var plan: PlanInfo
    var quantity: Int
    var unit_amount_in_cents: Int
    var tax_rate: Double?
    var subscription_add_ons: [AddOn]?
}

extension Date {
    func numberOfMonths(since: Date) -> UInt {
        // todo this should be the implementation, but has a bug (2018-11-28, should be solved in the next release?)
        // https://bugs.swift.org/browse/SR-7011
        // let components = Calendar.current.dateComponents([.month], from: since, to: self)
        // return UInt(components.month!) + 1

        let fc = Calendar.current.dateComponents([.month, .year], from: since)
        let tc = Calendar.current.dateComponents([.month, .year], from: self)
        
        let years = tc.year! - fc.year!
        let months = tc.month! - fc.month!
        
        return UInt((years * 12) + months)
    }
}
extension Subscription {
    var activeMonths: UInt {
        guard let act = activated_at, let end = current_period_ends_at else { return 0 }
        let toMinusOneDay = Calendar.current.date(byAdding: DateComponents(day: -1), to: end)!
        return toMinusOneDay.numberOfMonths(since: act)
    }

    func totalAtRenewal(addOn: Plan.AddOn) -> Int {
        let teamMemberPrice: Int
        if let a = subscription_add_ons?.first, a.add_on_code == addOn.add_on_code {
            teamMemberPrice = a.quantity * addOn.unit_amount_in_cents.usdCents
        } else {
            teamMemberPrice = 0
        }
        let beforeTax = unit_amount_in_cents * quantity + teamMemberPrice
        if let rate = tax_rate {
            return beforeTax + Int(Double(beforeTax) * rate)
        }
        return beforeTax
    }

    // Returns nil if there aren't any upgrades.
    var upgrade: Upgrade? {
        if state == .active, let m = Plan.monthly, plan.plan_code == m.plan_code, let y = Plan.yearly, let teamMemberPrice = y.teamMemberPrice {
            let teamMembers = subscription_add_ons?.first?.quantity ?? 0
            let totalWithoutVat = y.unit_amount_in_cents.usdCents + (teamMembers * teamMemberPrice)
            let vat: Int? = tax_rate.map { Int(Double(totalWithoutVat) * $0) }
            let total = totalWithoutVat + (vat ?? 0)
            return Upgrade(plan: y, total_without_vat: totalWithoutVat, total_in_cents: total, vat_in_cents: vat, tax_rate: tax_rate, team_members: teamMembers, per_team_member_in_cents: teamMemberPrice)
        } else {
            return nil
        }
    }

    struct Upgrade {
        let plan: Plan
        let total_without_vat: Int
        let total_in_cents: Int
        let vat_in_cents: Int?
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
    var adjustments: URL
    var account_balance: URL
    var billing_info: URL?
    var invoices: URL
    var redemption: URL?
    var subscriptions: URL
    var transactions: URL
    var account_code: String
    var state: State
    var username: String?
    var email: String
    var cc_emails: String?
    var first_name: String?
    var last_name: String?
    var company_name: String?
    var vat_number: String?
    var tax_exempt: Bool
    // var address: object
    var accept_language: String?
    var hosted_login_token: String
    var created_at: Date
    var updated_at: Date
    var closed_at: Date?
    var has_live_subscription: Bool
    var has_active_subscription: Bool
    var has_future_subscription: Bool
    var has_canceled_subscription: Bool
    var has_paused_subscription: String
    var has_past_due_invoice: Bool
    var preferred_locale: String?
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
    struct Subscription: Codable {
        var plan: Plan
        var uuid: String
        var state: String
        var activated_at: Date?
    }
    struct Plan: Codable {
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
    var coupon_type: String
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
}

struct CreateSubscription: Codable, RootElement {
    static let rootElementName: String = "subscription"
    struct CreateBillingInfo: Codable {
        var token_id: String
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

struct RecurlyError: Decodable {
    let field: String?
    let symbol: String?
    let message: String
}

enum RecurlyResult<A> {
    case success(A)
    case errors([RecurlyError])
}

struct RecurlyVoid: Decodable {
}

extension RecurlyResult: Decodable where A: Decodable {
    init(from decoder: Decoder) throws {
        do {
            let value = try A(from: decoder)
            self = .success(value)
        } catch {
            let value = try [RecurlyError](from: decoder)
            self = .errors(value)
        }
    }
}

extension Row where Element == UserData {
    var account: RemoteEndpoint<Account> {
        return recurly.account(with: id)
    }
    
    var invoices: RemoteEndpoint<[Invoice]> {
        return recurly.listInvoices(accountId: self.id.uuidString)
    }
    
    var subscriptions: RemoteEndpoint<[Subscription]> {
        return recurly.listSubscriptions(accountId: self.id.uuidString)
    }
    
    var redemptions: RemoteEndpoint<[Redemption]> {
        return recurly.redemptions(accountId: id.uuidString)
    }
    
    
    
    var currentSubscription: RemoteEndpoint<Subscription?> {
        return subscriptions.map { $0.first { $0.state == .active || $0.state == .canceled } }
    }
    
    var billingInfo: RemoteEndpoint<BillingInfo> {
        return recurly.billingInfo(accountId: id)
    }
    
    func updateBillingInfo(token: String) -> RemoteEndpoint<RecurlyResult<BillingInfo>> {
        return recurly.updatePaymentMethod(for: id, token: token)
    }
}

struct RecurlyErrors: Error {
    let errs: [RecurlyError]
    init(_ errs: [RecurlyError]) { self.errs = errs }
}

struct Recurly {
    let apiKey = env.recurlyApiKey
    let host = "\(env.recurlySubdomain).recurly.com"
    let base: URL
    var headers: [String:String] {
        return [
            "X-Api-Version": "2.13",
            "Content-Type": "application/xml; charset=utf-8",
            "Authorization": "Basic \(apiKey.base64Encoded)"
        ]
    }
    
    init() {
        self.base = URL(string: "https://\(host)/v2")!
    }
    
    var plans: RemoteEndpoint<[Plan]> {
        return RemoteEndpoint(xml: .get, url: base.appendingPathComponent("plans"), headers: headers)
    }
    
    var listAccounts: RemoteEndpoint<[Account]> {
        return RemoteEndpoint(xml: .get, url: base.appendingPathComponent("accounts"), headers: headers)
    }
    
    func billingInfo(accountId id: UUID) -> RemoteEndpoint<BillingInfo> {
        return RemoteEndpoint(xml: .get, url: base.appendingPathComponent("accounts/\(id.uuidString)/billing_info"), headers: headers)
    }
    
    func teamMemberAddOn(plan_code: String) -> RemoteEndpoint<Plan.AddOn> {
        return RemoteEndpoint(xml: .get, url: base.appendingPathComponent("plans/\(plan_code)/add_ons/\(teamMemberAddOnCode)"), headers: headers)
    }
    
    func updatePaymentMethod(for accountId: UUID, token: String) -> RemoteEndpoint<RecurlyResult<BillingInfo>> {
        struct UpdateData: Codable, RootElement {
            var token_id: String
            static let rootElementName = "billing_info"
        }
        return RemoteEndpoint(xml: .put, url: base.appendingPathComponent("accounts/\(accountId.uuidString)/billing_info"), value: UpdateData(token_id: token), headers: headers)
    }

    func account(with id: UUID) -> RemoteEndpoint<Account> {
        return RemoteEndpoint(xml: .get, url: base.appendingPathComponent("accounts/\(id.uuidString)"), headers: headers)
    }

    func listSubscriptions(accountId: String) -> RemoteEndpoint<[Subscription]> {
        return RemoteEndpoint(xml: .get, url: base.appendingPathComponent("accounts/\(accountId)/subscriptions"), headers: headers, query: ["per_page": "200"])
    }
    
    func listInvoices(accountId: String) -> RemoteEndpoint<[Invoice]> {
        return RemoteEndpoint(xml: .get, url: base.appendingPathComponent("accounts/\(accountId)/invoices"), headers: headers, query: ["per_page": "200"])
    }
    
    func redemptions(accountId: String) -> RemoteEndpoint<[Redemption]> {
        return RemoteEndpoint(xml: .get, url: base.appendingPathComponent("accounts/\(accountId)/redemptions"), headers: headers, query: ["per_page": "200"])
    }

    func createSubscription(_ x: CreateSubscription) -> RemoteEndpoint<RecurlyResult<Subscription>> {
        let url = base.appendingPathComponent("subscriptions")
        return RemoteEndpoint(xml: .post, url: url, value: x, headers: headers)
    }
    
    func cancel(_ subscription: Subscription) -> RemoteEndpoint<RecurlyResult<RecurlyVoid>> {
        let url = base.appendingPathComponent("subscriptions/\(subscription.uuid)/cancel")
        return RemoteEndpoint(xml: .put, url: url, headers: headers)
    }
    
    func reactivate(_ subscription: Subscription) -> RemoteEndpoint<RecurlyResult<RecurlyVoid>> {
        let url = base.appendingPathComponent("subscriptions/\(subscription.uuid)/reactivate")
        return RemoteEndpoint(xml: .put, url: url, headers: headers)
    }
    
    func updateSubscription(_ subscription: Subscription, plan_code: String? = nil, numberOfTeamMembers: Int? = nil) -> RemoteEndpoint<Subscription> {
        let addons: [UpdateSubscription.AddOn]? = numberOfTeamMembers == 0 ? nil : numberOfTeamMembers.map { [UpdateSubscription.AddOn(add_on_code: teamMemberAddOnCode, quantity: $0)] }
        let url = base.appendingPathComponent("subscriptions/\(subscription.uuid)")
        return RemoteEndpoint(xml: .put, url: url, value: UpdateSubscription(timeframe: "now", plan_code: plan_code, subscription_add_ons: addons), headers: headers, query: [:])
    }

    func coupon(code: String) -> RemoteEndpoint<Coupon> {
        let url = base.appendingPathComponent("coupons/\(code)")
        return RemoteEndpoint(xml: .get, url: url, headers: headers)
    }

    func coupons() -> RemoteEndpoint<[Coupon]> {
        let url = base.appendingPathComponent("coupons")
        return RemoteEndpoint(xml: .get, url: url, headers: headers)
    }

    func subscriptionStatus(for accountId: UUID) -> Promise<(subscriber: Bool, canceled: Bool, downloadCredits: UInt)?> {
        return Promise { cb in
            URLSession.shared.load(self.account(with: accountId)) { result in
                guard let acc = result else { cb(nil); return }
                URLSession.shared.load(recurly.listSubscriptions(accountId: acc.account_code)) { subs in
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

extension RemoteEndpoint where A: Decodable {
    init(xml method: Method, url: URL, headers: [String:String], query: [String:String] = [:]) {
        self.init(method, url: url, accept: .xml, headers: headers, query: query, parse: parseRecurlyResponse(url))
    }

    init<B: Encodable & RootElement>(xml method: Method, url: URL, value: B, headers: [String:String], query: [String:String] = [:]) {
        let data = try! encodeXML(value).data(using: .utf8)!
        print(try! encodeXML(value))
        self.init(method, url: url, accept: .xml, body: try! encodeXML(value).data(using: .utf8)!, headers: headers, query: query, parse: parseRecurlyResponse(url))
    }
}

private func parseRecurlyResponse<T: Decodable>(_ url: URL) -> (Data) -> T? {
    return { data in
//        print(String(data: data, encoding: .utf8)!)
        do {
            return try decodeXML(from: data)
        } catch {
            log(error: "Decoding error \(url): \(error), \(error.localizedDescription)")
            return nil
        }
    }
}
