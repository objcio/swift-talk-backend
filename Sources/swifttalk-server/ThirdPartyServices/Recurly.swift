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

struct CreateSubscription: Codable {
    struct CreateBillingInfo: Codable {
        var token_id: String
    }
    struct CreateAccount: Codable {
        var code: UUID // Recurly allows more things than this, but we'll just go for the UUID
        var email: String
        var billing_info: CreateBillingInfo
    }
    var plan_code: String
    var currency: String = "USD"
    var coupon_code: String? = nil
    var account: CreateAccount
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
}

extension RemoteEndpoint where A: Codable {
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
}
