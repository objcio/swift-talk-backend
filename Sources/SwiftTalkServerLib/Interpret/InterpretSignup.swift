//
//  InterpretSignup.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import Database
import WebServer
import Base

extension Route.Signup {
    func interpret<I: STResponse>() throws -> I where I.Env == STRequestEnvironment {
        switch self {
        
        case .subscribe(let planName):
            if let p = planName {
                return I.withSession { _ in
                    guard let _ = Plan.find(code: p) else { throw ServerError(privateMessage: "No such plan \(p)")}
                    return I.redirect(to: .subscription(.new(couponCode: nil, planCode: p, team: false)))
                }
            } else {
                guard let monthly = Plan.monthly, let yearly = Plan.yearly else {
                    throw ServerError(privateMessage: "Can't find monthly or yearly plan: \([Plan.all])")
                }
                return .write(html: renderSubscribe(monthly: monthly, yearly: yearly))
            }
        
        case .subscribeTeam:
            guard let monthly = Plan.monthly, let yearly = Plan.yearly else {
                throw ServerError(privateMessage: "Can't find monthly or yearly plan: \([Plan.all])")
            }
            return .write(html: renderSubscribeTeam(monthly: monthly, yearly: yearly))
        
        case .teamMember(let token):
            return .query(Row<UserData>.select(teamToken: token)) { row in
                let teamManager = try row ?! ServerError(privateMessage: "signup token doesn't exist: \(token)", publicMessage: "This signup link is invalid. Please get in touch with your team manager for a new one.")
                return .withSession { session in
                    if let s = session {
                        if s.user.id == teamManager.id && s.selfPremiumAccess {
                            return .write(html: teamMemberSubscribeForAlreadyPartOfThisTeam())
                        } else if s.selfPremiumAccess {
                            return .write(html: teamMemberSubscribeForSelfSubscribed(signupToken: token))
                        } else if s.isTeamMemberOf(teamManager) {
                            return .write(html: teamMemberSubscribeForAlreadyPartOfThisTeam())
                        } else {
                            return .write(html: teamMemberSubscribeForSignedIn(signupToken: token))
                        }
                    } else {
                        return .write(html: teamMemberSubscribe(signupToken: token))
                    }
                }
            }
        
        case .promoCode(let str):
            return .onSuccess(promise: recurly.coupon(code: str).promise, message: "Can't find that coupon.", do: { coupon in
                guard coupon.state == "redeemable" else {
                    throw ServerError(privateMessage: "not redeemable: \(str)", publicMessage: "This coupon is not redeemable anymore.")
                }
                guard let m = Plan.monthly, let y = Plan.yearly else {
                    throw ServerError(privateMessage: "Plans not loaded", publicMessage: "A small hiccup. Please try again in a little while.")
                }
                return .write(html: renderSubscribe(monthly: m, yearly: y, coupon: coupon))
            })
        }
    }
}
