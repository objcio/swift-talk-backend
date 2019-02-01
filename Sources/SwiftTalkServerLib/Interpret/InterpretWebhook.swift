//
//  InterpretWebhook.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import Base


extension Route.Webhook {
    func interpret<I: Interp>() throws -> I {
        switch self {
        
        case .recurlyWebhook:
            return I.withPostData { data in
                guard let webhook: Webhook = try? decodeXML(from: data) else { return I.write("", status: .ok) }
                let id = webhook.account.account_code
                recurly.subscriptionStatus(for: webhook.account.account_code).run { status in
                    let c = lazyConnection()
                    guard let s = status else {
                        return log(error: "Received Recurly webhook for account id \(id), but couldn't load this account from Recurly")
                    }
                    guard let r = try? c.get().execute(Row<UserData>.select(id)), var row = r else {
                        return log(error: "Received Recurly webhook for account \(id), but didn't find user in database")
                    }
                    row.data.subscriber = s.subscriber
                    row.data.downloadCredits = Int(s.downloadCredits)
                    row.data.canceled = s.canceled
                    tryOrLog("Failed to update user \(id) in response to Recurly webhook") { try c.get().execute(row.update()) }
                }
                
                return catchAndDisplayError {
                    if let s = webhook.subscription, s.plan.plan_code.hasPrefix("gift") {
                        return I.query(Row<GiftData>.select(subscriptionId: s.uuid)) {
                            if var gift = flatten($0) {
                                log(info: "gift update \(s) \(gift)")
                                let ok = { I.write("", status: .ok) }
                                if s.state == "future", let a = s.activated_at {
                                    if gift.data.sendAt != a {
                                        gift.data.sendAt = a
                                        return I.query(gift.update(), ok)
                                    }
                                } else if s.state == "active" {
                                    if !gift.data.activated {
                                        let plan = Plan.gifts.first { $0.plan_code == s.plan.plan_code }
                                        let duration = plan?.prettyDuration ?? "unknown"
                                        let email = sendgrid.send(to: gift.data.gifteeEmail, name: gift.data.gifteeName, subject: "We have a gift for you...", text: gift.gifteeEmailText(duration: duration))
                                        log(info: "Sending gift email to \(gift.data.gifteeEmail)")
                                        globals.urlSession.load(email) { result in
                                            if result == nil {
                                                log(error: "Can't send email for gift \(gift)")
                                            }
                                        }
                                        gift.data.activated = true
                                        return I.query(gift.update(), ok)
                                    }
                                }
                                return ok()
                            } else {
                                log(error: "Got a recurly webhook but can't find gift \(s)")
                                return I.write("", status: .internalServerError)
                            }
                        }
                    }
                    return I.write("")
                }
            }

        case .githubWebhook:
            // This could be done more fine grained, but this works just fine for now
            refreshStaticData()
            return I.write("")
        }
    }
}
