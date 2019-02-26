//
//  InterpretSubscription.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import Base
import Database
import WebServer


extension Route.Subscription {
    func interpret<I: STResponse>() throws -> I where I.Env == STRequestEnvironment {
        return .requireSession { sess in
            try self.interpret(sesssion: sess)
        }
    }

    private func interpret<I: STResponse>(sesssion sess: Session) throws -> I where I.Env == STRequestEnvironment {
        func newSubscription(couponCode: String?, team: Bool, errs: [String]) throws -> I {
            if let c = couponCode {
                return .onSuccess(promise: recurly.coupon(code: c).promise, do: { coupon in
                    return try .write(html: newSub(coupon: coupon, team: team, errs: errs))
                })
            } else {
                return try .write(html: newSub(coupon: nil, team: team, errs: errs))
            }
        }

        let user = sess.user
        switch self {
            
        case let .create(couponCode, team):
            return .verifiedPost { dict in
                guard let planId = dict["plan_id"], let token = dict["billing_info[token]"] else {
                    throw ServerError(privateMessage: "Incorrect post data")
                }
                let plan = try Plan.all.first(where: { $0.plan_code == planId }) ?! ServerError.init(privateMessage: "Illegal plan: \(planId)", publicMessage: "Couldn't find the plan you selected.")
                let cr = CreateSubscription.init(plan_code: plan.plan_code, currency: "USD", coupon_code: couponCode, starts_at: nil, account: .init(account_code: user.id, email: user.data.email, billing_info: .init(token_id: token)))
                return .onSuccess(promise: recurly.createSubscription(cr).promise, message: "Something went wrong, please try again", do: { sub_ in
                    switch sub_ {
                    case .errors(let messages):
                        log(RecurlyErrors(messages))
                        if messages.contains(where: { $0.field == "subscription.account.email" && $0.symbol == "invalid_email" }) {
                            let response = registerForm(couponCode: couponCode, team: team).render(.init(user.data), [ValidationError("email", "Please provide a valid email address and try again.")])
                            return .write(html: response)
                        }
                        return try newSubscription(couponCode: couponCode, team: team, errs: messages.map { $0.message })
                    case .success(let sub):
                        return .query(user.changeSubscriptionStatus(sub.state == .active)) {
                            // todo: flash: "Thank you for supporting us
                            .redirect(to: team ? .account(.teamMembers) : .home)
                        }
                    }
                })
            }
        
        case let .new(couponCode, team):
            if !user.data.confirmedNameAndEmail {
                let resp = registerForm(couponCode: couponCode, team: team).render(.init(user.data), [])
                return .write(html: resp)
            } else {
                return .query(Task.unfinishedSubscriptionReminder(userId: user.id).schedule(weeks: 1)) {
                    var u = user
                    u.data.role = team ? .teamManager : .user
                    return .query(u.update()) {
                        try newSubscription(couponCode: couponCode, team: team, errs: [])
                    }
                }
            }
        
        case let .registerAsTeamMember(token, terminate):
            return .query(Row<UserData>.select(teamToken: token)) { row in
                let teamManager = try row ?!
                    ServerError(privateMessage: "signup token doesn't exist: \(token)", publicMessage: "This signup link is invalid. Please get in touch with your team manager for a new one.")
                func registerTeamMember() -> I {
                    let teamMemberData = TeamMemberData(userId: teamManager.id, teamMemberId: user.id)
                    return .query(teamMemberData.insert) { _ in
                        return .execute(Task.syncTeamMembersWithRecurly(userId: teamManager.id).schedule(minutes: 5)) { _ in
                            if !user.data.confirmedNameAndEmail {
                                let resp = registerForm(couponCode: nil, team: false).render(.init(user.data), [])
                                return .write(html: resp)
                            } else {
                                return .redirect(to: .home)
                            }
                        }
                    }
                }
                
                if sess.selfPremiumAccess == true {
                    if terminate {
                        return .onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                            return .onSuccess(promise: recurly.terminate(sub, refund: .partial).promise) { result in
                                switch result {
                                case .success: return registerTeamMember()
                                case .errors(let errs): throw RecurlyErrors(errs)
                                }
                            }
                        }
                    } else {
                        return .redirect(to: .signup(.teamMember(token: token)))
                    }
                } else {
                    return registerTeamMember()
                }
            }
        
        case .cancel:
            return .verifiedPost { _ in
                return .onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                    guard sub.state == .active else {
                        throw ServerError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find an active subscription.")
                    }
                    return .onSuccess(promise: recurly.cancel(sub).promise) { result in
                        switch result {
                        case .success: return .redirect(to: .account(.billing))
                        case .errors(let errs): throw RecurlyErrors(errs)
                        }
                    }
                    
                }
            }
        
        case .upgrade:
            return .verifiedPost { _ in
                return .onSuccess(promise: sess.user.currentSubscription.promise.map(flatten), do: { sub throws -> I in
                    let u = try sub.upgrade(vatExempt: false) ?! ServerError(privateMessage: "no upgrade available \(sub)", publicMessage: "There's no upgrade available.")
                    return .query(sess.user.teamMembers) { teamMembers in
                        .onSuccess(promise: recurly.updateSubscription(sub, plan_code: u.plan.plan_code, numberOfTeamMembers: teamMembers.count).promise, do: { result throws -> I in
                            .redirect(to: .account(.billing))
                        })
                    }
                })
            }
        
        case .reactivate:
            return .verifiedPost { _ in
                return .onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                    guard sub.state == .canceled else {
                        throw ServerError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find a cancelled subscription.")
                    }
                    return .onSuccess(promise: recurly.reactivate(sub).promise) { result in
                        switch result {
                        case .success:
                            // todo: flash: "Thank you for supporting us
                            return .redirect(to: .home)
                        case .errors(let errs):
                            throw RecurlyErrors(errs)
                        }
                    }
                    
                }
            }
            
        }
    }
}
