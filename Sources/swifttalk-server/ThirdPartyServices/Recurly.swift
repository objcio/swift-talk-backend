//
//  Recurly.swift
//  Bits
//
//  Created by Chris Eidhof on 13.08.18.
//

import Foundation

extension String {
    var base64Encoded: String {
        return data(using: .utf8)!.base64EncodedString()
    }
}

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
        if let m = Plan.monthly, plan.plan_code == m.plan_code, let y = Plan.yearly {
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
    var address: String?
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

struct UpdateSubscriptionAddOns: Codable, RootElement {
    static let rootElementName = "subscription"
    struct AddOn: Codable, RootElement {
        static let rootElementName: String = "subscription_add_on"
        var add_on_code = "team_members"
        var quantity: Int
    }
    var subscription_add_ons: [AddOn]
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

struct Recurly {
    let base: URL
    let apiKey: String
    let subdomain: String
    var headers: [String:String] {
        return [
            "X-Api-Version": "2.13",
            "Content-Type": "application/xml; charset=utf-8",
            "Authorization": "Basic \(apiKey.base64Encoded)"
        ]
    }
    
    init(subdomain: String, apiKey: String) {
        base = URL(string: "https://\(subdomain)/v2")!
        self.subdomain = subdomain
        self.apiKey = apiKey
    }    
    
    var plans: RemoteEndpoint<[Plan]> {
        return RemoteEndpoint<[Plan]>(getXML: base.appendingPathComponent("plans"), headers: headers, query: [:])
    }
    
    var listAccounts: RemoteEndpoint<[Account]> {
        return RemoteEndpoint(getXML: base.appendingPathComponent("accounts"), headers: headers, query: [:])
    }
    
    func billingInfo(with id: UUID) -> RemoteEndpoint<BillingInfo> {
        return RemoteEndpoint(getXML: base.appendingPathComponent("accounts/\(id.uuidString)/billing_info"), headers: headers, query: [:])
    }

    func account(with id: UUID) -> RemoteEndpoint<Account> {
        return RemoteEndpoint(getXML: base.appendingPathComponent("accounts/\(id.uuidString)"), headers: headers, query: [:])
    }

    func listSubscriptions(accountId: String) -> RemoteEndpoint<[Subscription]> {
        return RemoteEndpoint(getXML: base.appendingPathComponent("accounts/\(accountId)/subscriptions"), headers: headers, query: ["per_page": "200"])
    }
    
    func listInvoices(accountId: String) -> RemoteEndpoint<[Invoice]> {
        return RemoteEndpoint(getXML: base.appendingPathComponent("accounts/\(accountId)/invoices"), headers: headers, query: ["per_page": "200"])
    }

    func createSubscription(_ x: CreateSubscription) -> RemoteEndpoint<RecurlyResult<Subscription>> {
        let url = base.appendingPathComponent("subscriptions")
        return RemoteEndpoint(postXML: url, value: x, headers: headers, query: [:])
    }
    
    func updateTeamMembers(quantity: Int, subscriptionId: String) -> RemoteEndpoint<Subscription> {
        let url = base.appendingPathComponent("subscriptions/\(subscriptionId)")
        let data = UpdateSubscriptionAddOns(subscription_add_ons: [UpdateSubscriptionAddOns.AddOn(add_on_code: "team_members", quantity: quantity)])
        return RemoteEndpoint(putXML: url, value: data, headers: headers, query: [:])
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
        return URL(string: "https://\(subdomain)/account/invoices/\(invoice.invoice_number).pdf?ht=\(hostedLoginToken)")!
    }
}

extension RemoteEndpoint where A: Decodable {
    init(getXML get: URL, headers: [String:String], query: [String:String]) {
        self.init(get: get, accept: .xml, headers: headers, query: query, parse: parseRecurlyResponse)
    }
    
    init<B: Encodable & RootElement>(postXML url: URL, value: B, headers: [String:String], query: [String:String]) {
        self.init(post: url, accept: .xml, body: try! encodeXML(value).data(using: .utf8)!, headers: headers, query: query, parse: parseRecurlyResponse)
    }

    init<B: Encodable & RootElement>(putXML url: URL, value: B, headers: [String:String], query: [String:String]) {
        self.init(put: url, accept: .xml, body: try! encodeXML(value).data(using: .utf8)!, headers: headers, query: query, parse: parseRecurlyResponse)
    }
}

private func parseRecurlyResponse<T: Decodable>(_ data: Data) -> T? {
    do {
        print(String(data: data, encoding: .utf8)!)
        return try decodeXML(from: data)
    } catch {
        print("Decoding error: \(error), \(error.localizedDescription)", to: &standardError)
        return nil
    }
}
