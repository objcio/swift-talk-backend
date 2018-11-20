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
}

struct Plan: Codable {
    enum IntervalUnit: String, Codable {
        case months
        case days
    }
    var plan_code: String
    var name: String
    var description: String?
    var plan_interval_length: Int
    var plan_interval_unit: IntervalUnit
    var unit_amount_in_cents: Amount
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
    var subscription_add_ons: [AddOn]
}

extension Subscription {
    var activeMonths: UInt {
        guard let act = activated_at, let end = current_period_ends_at else { return 0 }
        let toMinusOneDay = Calendar.current.date(byAdding: DateComponents(day: -1), to: end)!
        let components = Calendar.current.dateComponents([.month], from: act, to: toMinusOneDay)
        return UInt(components.month!) + 1
    }

    // Todo: this should include the team members as well.
    var totalAtRenewal: Int {
        let beforeTax = unit_amount_in_cents * quantity
        if let rate = tax_rate {
            return beforeTax + Int(Double(beforeTax) * rate)
        }
        return beforeTax
    }

    // Returns nil if there aren't any upgrades.
    var upgrade: Upgrade? {
        if state == .active, let m = Plan.monthly, plan.plan_code == m.plan_code, let y = Plan.yearly {
            // TODO calculate correctly
            let totalWithoutVat = y.unit_amount_in_cents.usdCents // todo add team members
            let vat: Int? = tax_rate.map { Int(Double(totalWithoutVat) * $0) }
            let total = totalWithoutVat + (vat ?? 0)
            return Upgrade(plan: y, total_without_vat: totalWithoutVat, total_in_cents: total, vat_in_cents: vat, tax_rate: tax_rate, team_members: 0, per_team_member_in_cents: 78)
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
}

struct WebhookAccount: Codable {
    var account_code: UUID
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
    var account: CreateAccount
}

struct UpdateSubscription: Codable, RootElement {
    static let rootElementName = "subscription"
    struct AddOn: Codable, RootElement {
        static let rootElementName: String = "subscription_add_on"
        var add_on_code = "team_members"
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
    let field: String
    let symbol: String
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
    var monthsOfActiveSubscription: Promise<UInt?> {
        return recurly.subscriptionStatus(for: self.id).map { status in
            guard let s = status else { log(error: "Couldn't fetch subscription status for user \(self.id) from Recurly"); return nil }
            return s.months
        }
    }
    
    var account: RemoteEndpoint<Account> {
        return recurly.account(with: id)
    }
    
    var invoices: RemoteEndpoint<[Invoice]> {
        return recurly.listInvoices(accountId: self.id.uuidString)
    }
    
    var subscriptions: RemoteEndpoint<[Subscription]> {
        return recurly.listSubscriptions(accountId: self.id.uuidString)
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
        let addons: [UpdateSubscription.AddOn]? = numberOfTeamMembers.map { [UpdateSubscription.AddOn(add_on_code: "team_members", quantity: $0)] }
        let url = base.appendingPathComponent("subscriptions/\(subscription.uuid)")
        return RemoteEndpoint(xml: .put, url: url, value: UpdateSubscription(timeframe: "now", plan_code: plan_code, subscription_add_ons: addons), headers: headers, query: [:])
    }

    func subscriptionStatus(for accountId: UUID) -> Promise<(subscriber: Bool, months: UInt)?> {
        return Promise { cb in
            URLSession.shared.load(self.account(with: accountId)) { result in
                guard let acc = result else { cb(nil); return }
                URLSession.shared.load(recurly.listSubscriptions(accountId: acc.account_code)) { subs in
                    cb((acc.subscriber, (subs?.activeMonths ?? 0) * 4))
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
        self.init(method, url: url, accept: .xml, headers: headers, query: query, parse: parseRecurlyResponse)
    }

    init<B: Encodable & RootElement>(xml method: Method, url: URL, value: B, headers: [String:String], query: [String:String] = [:]) {
        self.init(method, url: url, accept: .xml, body: try! encodeXML(value).data(using: .utf8)!, headers: headers, query: query, parse: parseRecurlyResponse)
    }
}

private func parseRecurlyResponse<T: Decodable>(_ data: Data) -> T? {
    do {
//        print(String(data: data, encoding: .utf8)!)
        return try decodeXML(from: data)
    } catch {
        print("Decoding error: \(error), \(error.localizedDescription)", to: &standardError)
        return nil
    }
}
