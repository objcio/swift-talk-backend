//
//  InterpretSubscription.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import PostgreSQL

extension Route.Subscription {
    func interpret<I: SwiftTalkInterpreter>(sesssion sess: Session, context: Context, connection c: Lazy<Connection>) throws -> I {
        let user = sess.user
        func newSubscription(couponCode: String?, errs: [String]) throws -> I {
            if let c = couponCode {
                return I.onSuccess(promise: recurly.coupon(code: c).promise, do: { coupon in
                    return try I.write(newSub(context: context, csrf: sess.user.data.csrf, coupon: coupon, errs: errs))
                })
            } else {
                return try I.write(newSub(context: context, csrf: sess.user.data.csrf, coupon: nil, errs: errs))
            }
        }
        
        switch self {
        case .create(let couponCode):
            return I.withPostBody(csrf: sess.user.data.csrf) { dict in
                guard let planId = dict["plan_id"], let token = dict["billing_info[token]"] else {
                    throw ServerError(privateMessage: "Incorrect post data", publicMessage: "Something went wrong")
                }
                let plan = try Plan.all.first(where: { $0.plan_code == planId }) ?! ServerError.init(privateMessage: "Illegal plan: \(planId)", publicMessage: "Couldn't find the plan you selected.")
                let cr = CreateSubscription.init(plan_code: plan.plan_code, currency: "USD", coupon_code: couponCode, starts_at: nil, account: .init(account_code: user.id, email: user.data.email, billing_info: .init(token_id: token)))
                return I.onSuccess(promise: recurly.createSubscription(cr).promise, message: "Something went wrong, please try again", do: { sub_ in
                    switch sub_ {
                    case .errors(let messages):
                        log(RecurlyErrors(messages))
                        if messages.contains(where: { $0.field == "subscription.account.email" && $0.symbol == "invalid_email" }) {
                            let response = registerForm(context, couponCode: couponCode).render(.init(user.data), user.data.csrf, [ValidationError("email", "Please provide a valid email address and try again.")])
                            return I.write(response)
                        }
                        return try newSubscription(couponCode: couponCode, errs: messages.map { $0.message })
                    case .success(let sub):
                        try c.get().execute(user.changeSubscriptionStatus(sub.state == .active))
                        return I.redirect(to: .account(.thankYou))
                    }
                })
            }
        case .new(let couponCode):
            if !user.data.confirmedNameAndEmail {
                let resp = registerForm(context, couponCode: couponCode).render(.init(user.data), user.data.csrf, [])
                return I.write(resp)
            } else {
                try c.get().execute(Task.unfinishedSubscriptionReminder(userId: user.id).schedule(weeks: 1))
                return try newSubscription(couponCode: couponCode, errs: [])
            }
        case .cancel:
            return I.withPostBody(csrf: user.data.csrf) { _ in
                return I.onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                    guard sub.state == .active else {
                        throw ServerError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find an active subscription.")
                    }
                    return I.onSuccess(promise: recurly.cancel(sub).promise) { result in
                        switch result {
                        case .success: return I.redirect(to: .account(.billing))
                        case .errors(let errs): throw RecurlyErrors(errs)
                        }
                    }
                    
                }
            }
        case .upgrade:
            return I.withPostBody(csrf: sess.user.data.csrf) { _ in
                return I.onSuccess(promise: sess.user.currentSubscription.promise.map(flatten), do: { sub throws -> I in
                    guard let u = sub.upgrade else { throw ServerError(privateMessage: "no upgrade available \(sub)", publicMessage: "There's no upgrade available.")}
                    let teamMembers = try c.get().execute(sess.user.teamMembers)
                    return I.onSuccess(promise: recurly.updateSubscription(sub, plan_code: u.plan.plan_code, numberOfTeamMembers: teamMembers.count).promise, do: { result throws -> I in
                        return I.redirect(to: .account(.billing))
                    })
                })
            }
        case .reactivate:
            return I.withPostBody(csrf: user.data.csrf) { _ in
                return I.onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                    guard sub.state == .canceled else {
                        throw ServerError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find a cancelled subscription.")
                    }
                    return I.onSuccess(promise: recurly.reactivate(sub).promise) { result in
                        switch result {
                        case .success: return I.redirect(to: .account(.thankYou))
                        case .errors(let errs): throw RecurlyErrors(errs)
                        }
                    }
                    
                }
            }
        }
    }
}
