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
        case usd = "USD"
    }
    var usd: Int
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
    var state: State
    var activated_at: Date?
    var expires_at: Date?
    var current_period_ends_at: Date?
}

extension Subscription {
    var activeMonths: UInt {
        guard let act = activated_at, let end = current_period_ends_at else { return 0 }
        let toMinusOneDay = Calendar.current.date(byAdding: DateComponents(day: -1), to: end)!
        let components = Calendar.current.dateComponents([.month], from: act, to: toMinusOneDay)
        return UInt(components.month!) + 1
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
    var headers: [String:String] {
        return [
            "X-Api-Version": "2.13",
            "Content-Type": "application/xml; charset=utf-8",
            "Authorization": "Basic \(apiKey.base64Encoded)"
        ]
    }
    
    init(subdomain: String, apiKey: String) {
        base = URL(string: "https://\(subdomain)/v2")!
        self.apiKey = apiKey
    }    
    
    var plans: RemoteEndpoint<[Plan]> {
        return RemoteEndpoint<[Plan]>(getXML: base.appendingPathComponent("plans"), headers: headers, query: [:])
    }
    
    var listAccounts: RemoteEndpoint<[Account]> {
        return RemoteEndpoint(getXML: base.appendingPathComponent("accounts"), headers: headers, query: [:])
    }
    
    func account(with id: UUID) -> RemoteEndpoint<Account> {
        return RemoteEndpoint(getXML: base.appendingPathComponent("accounts/\(id.uuidString)"), headers: headers, query: [:])
    }

    func listSubscriptions(accountId: String) -> RemoteEndpoint<[Subscription]> {
        return RemoteEndpoint(getXML: base.appendingPathComponent("accounts/\(accountId)/subscriptions"), headers: headers, query: ["per_page": "200"])
    }
    
    func createSubscription(_ x: CreateSubscription) -> RemoteEndpoint<RecurlyResult<Subscription>> {
        let url = base.appendingPathComponent("subscriptions")
        return RemoteEndpoint(postXML: url, value: x, headers: headers, query: [:])
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
}

extension RemoteEndpoint where A: Decodable {
    init(getXML get: URL, headers: [String:String], query: [String:String]) {
        self.init(get: get, accept: .xml, headers: headers, query: query, parse: { data in
            do {
                return try decodeXML(from: data)
            } catch {
                print("Decoding error: \(error), \(error.localizedDescription)", to: &standardError)
                return nil
            }
        })
    }
    
    init<B: Encodable & RootElement>(postXML url: URL, value: B, headers: [String:String], query: [String:String]) {
        self.init(post: url, accept: .xml, body: try! encodeXML(value).data(using: .utf8)!, headers: headers, query: query, parse: { data in
            do {
                return try decodeXML(from: data)
            } catch {
                print("Decoding error: \(error), \(error.localizedDescription)", to: &standardError)
                return nil
            }
        })
    }
}
