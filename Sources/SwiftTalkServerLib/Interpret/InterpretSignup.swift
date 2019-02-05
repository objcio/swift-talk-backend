////
////  InterpretSignup.swift
////  SwiftTalkServerLib
////
////  Created by Florian Kugler on 01-02-2019.
////
//
//import Foundation
//import Database
//
//
//extension Route.Signup {
//    func interpret<I: Interp>() throws -> I where I.RE == STRequestEnvironment {
//        switch self {
//        
//        case .subscribe:
//            guard let monthly = Plan.monthly, let yearly = Plan.yearly else {
//                throw ServerError(privateMessage: "Can't find monthly or yearly plan: \([Plan.all])", publicMessage: "Something went wrong, please try again later")
//            }
//            return I.write(renderSubscribe(monthly: monthly, yearly: yearly))
//        
//        case .subscribeTeam:
//            guard let monthly = Plan.monthly, let yearly = Plan.yearly else {
//                throw ServerError(privateMessage: "Can't find monthly or yearly plan: \([Plan.all])", publicMessage: "Something went wrong, please try again later")
//            }
//            return I.write(renderSubscribeTeam(monthly: monthly, yearly: yearly))
//        
//        case .teamMember(let token):
//            return I.query(Row<UserData>.select(teamToken: token)) { row in
//                guard let teamManager = row else {
//                    throw ServerError(privateMessage: "signup token doesn't exist: \(token)", publicMessage: "This signup link is invalid. Please get in touch with your team manager for a new one.")
//                }
//                return I.withSession { session in
//                    if let s = session {
//                        if s.user.id == teamManager.id && s.selfPremiumAccess {
//                            return I.write(teamMemberSubscribeForAlreadyPartOfThisTeam())
//                        } else if s.selfPremiumAccess {
//                            return I.write(teamMemberSubscribeForSelfSubscribed(signupToken: token))
//                        } else if s.isTeamMemberOf(teamManager) {
//                            return I.write(teamMemberSubscribeForAlreadyPartOfThisTeam())
//                        } else {
//                            return I.write(teamMemberSubscribeForSignedIn(signupToken: token))
//                        }
//                    } else {
//                        return I.write(teamMemberSubscribe(signupToken: token))
//                    }
//                }
//            }
//        
//        case .promoCode(let str):
//            return I.onSuccess(promise: recurly.coupon(code: str).promise, message: "Can't find that coupon.", do: { coupon in
//                guard coupon.state == "redeemable" else {
//                    throw ServerError(privateMessage: "not redeemable: \(str)", publicMessage: "This coupon is not redeemable anymore.")
//                }
//                guard let m = Plan.monthly, let y = Plan.yearly else {
//                    throw ServerError(privateMessage: "Plans not loaded", publicMessage: "A small hiccup. Please try again in a little while.")
//                }
//                return I.write(renderSubscribe(monthly: m, yearly: y, coupon: coupon))
//            })
//        }
//    }
//}
