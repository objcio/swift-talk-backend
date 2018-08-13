//
//  Recurly.swift
//  Bits
//
//  Created by Chris Eidhof on 13.08.18.
//

import Foundation
import XMLParsing

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

struct Plans: Codable {
    var plans: [Plan]
    
    enum CodingKeys: String, CodingKey {
        case plans = "plan"
    }
}

struct Plan: Codable {
    var plan_code: String
    var name: String
    var description: String?
    var plan_interval_length: Int
    var plan_interval_unit: String
    var unit_amount_in_cents: Amount
}


struct Accounts: Codable {
    var accounts: [Account]
    
    enum CodingKeys: String, CodingKey {
        case accounts = "account"
    }
}

struct RecurlyURL: Codable {
    let href: URL
}

enum RecurlyOptional<Value>: Codable where Value: Codable {
    init(from decoder: Decoder) throws {
        do {
            self = .some(try decoder.singleValueContainer().decode(Value.self))
        } catch {
        	self = .none
        }
    }
    
    func encode(to encoder: Encoder) throws {
        fatalError()
    }
    
    case none
    case some(Value)
}


struct Account: Codable {
    enum State: String, Codable {
        case active, closed, subscriber, non_subscriber, past_due
    }
    var adjustments:    RecurlyURL
    var account_balance:    RecurlyURL
    var billing_info:    RecurlyURL?
    var invoices:    RecurlyURL
    var redemption:    RecurlyURL?
    var subscriptions:    RecurlyURL
    var transactions:    RecurlyURL
    var account_code:    String
    var state:    State
//    var username:    String?
    var email:    String
    var cc_emails:    RecurlyOptional<String>?
    var first_name:    RecurlyOptional<String>
    var last_name:    RecurlyOptional<String>
    var company_name:    RecurlyOptional<String>
    var vat_number:    RecurlyOptional<String>
    var tax_exempt:    Bool
//    var address:    object
    var accept_language: RecurlyOptional<String>
    var hosted_login_token:    String
    var created_at:    Date
    var updated_at:    Date
    var closed_at:    RecurlyOptional<Date>
    var has_live_subscription:    Bool
    var has_active_subscription:    Bool
    var has_future_subscription:    Bool
    var has_canceled_subscription:    Bool
    var has_paused_subscription:    String
    var has_past_due_invoice:    Bool
    var preferred_locale:    RecurlyOptional<String>
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
        return RemoteEndpoint<Plans>(get: base.appendingPathComponent("plans"), accept: .xml, headers: headers, query: [:]).map { $0.plans }
    }
    
    var listAccounts: RemoteEndpoint<[Account]> {
        return RemoteEndpoint<Accounts>(get: base.appendingPathComponent("accounts"), accept: .xml, headers: headers, query: [:]).map { $0.accounts }
    }
}
