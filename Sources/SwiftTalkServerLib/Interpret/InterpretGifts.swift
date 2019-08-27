//
//  InterpretGifts.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import Base
import Database
import WebServer


extension Route.Gifts {
    func interpret<I: STResponse>() throws -> I where I.Env == STRequestEnvironment {
        
        func showPaymentForm(giftId: UUID, errors: [ValidationError] = []) throws -> I {
            return .query(Row<GiftData>.select(giftId)) { g in
                let gift = try g ?! ServerError(privateMessage: "No such gift")
                guard gift.data.subscriptionId == nil else {
                    throw ServerError(privateMessage: "Already paid \(gift.id)", publicMessage: "You already paid this gift.")
                }
                let plan = try Plan.gifts.first(where: { $0.plan_code == gift.data.planCode }) ?! ServerError.init(privateMessage: "Illegal plan: \(gift.data.planCode)", publicMessage: "Couldn't find the plan you selected.")
                let f = payGiftForm(plan: plan, gift: gift.data, route: .gift(.pay(gift.id)))
                return I.form(f, initial: .init(), validate: { $0.validate() }, onPost: { result in
                    return I.query(UserData(email: result.gifter_email, avatarURL: "", name: "").insert) { userId in
                        var copy = gift
                        copy.data.gifterUserId = userId
                        copy.data.gifterEmail = result.gifter_email
                        copy.data.gifterName = result.gifter_name
                        return .query(copy.update()) {
                            return createGiftSubscription(giftId: gift.id, recurlyToken: result.token)
                        }
                    }
                })
            }
        }
        
        func createGiftSubscription(giftId: UUID, recurlyToken: String, threeDResultToken: String? = nil) -> I {
            return .query(Row<GiftData>.select(giftId)) { g in
                let gift = try g ?! ServerError(privateMessage: "No such gift")
                let start = gift.data.sendAt > globals.currentDate() ? gift.data.sendAt : nil // no start date means starting immediately
                guard let gifterEmail = gift.data.gifterEmail else { throw ServerError(privateMessage: "Must have gifter email") }
                guard let userId = gift.data.gifterUserId else { throw ServerError(privateMessage: "Must have gifter user id") }
                let cr = CreateSubscription(plan_code: gift.data.planCode, currency: "USD", coupon_code: nil, starts_at: start, account: .init(account_code: userId, email: gifterEmail, billing_info: .init(token_id: recurlyToken, three_d_secure_action_result_token_id: threeDResultToken)))
                return .onSuccess(promise: recurly.createSubscription(cr).promise, message: "Something went wrong, please try again", do: { sub_ in
                    switch sub_ {
                    case .error(let error):
                        log(error)
                        if let threeDActionToken = error.threeDActionToken {
                            let success = ThreeDSuccessRoute { token in
                                .gift(.threeDSecureResponse(threeDResultToken: token, recurlyToken: recurlyToken, giftId: gift.id))
                            }
                            let otherPaymentMethod = Route.gift(.pay(gift.id))
                            return .redirect(to: .threeDSecureChallenge(threeDActionToken: threeDActionToken, success: success, otherPaymentMethod: otherPaymentMethod))
                        } else {
                            return try showPaymentForm(giftId: giftId, errors: [("", error.error.message)])
                        }
                    case .success(let sub):
                        var copy = gift
                        copy.data.subscriptionId = sub.uuid
                        return .query(copy.update()) {
                            if start != nil {
                                let email = sendgrid.send(to: gifterEmail, name: copy.data.gifterName ?? "", subject: "Thank you for gifting Swift Talk", text: copy.data.gifterEmailText)
                                globals.urlSession.load(email) { result in
                                    myAssert(result != nil)
                                }
                            }
                            return .redirect(to: .gift(.thankYou(gift.id)))
                        }
                    }
                })
            }
        }
        
        switch self {
            
        case .home:
            return try .write(html: giftHome(plans: Plan.gifts))
        
        case .new(let planCode):
            let plan = try Plan.gifts.first(where: { $0.plan_code == planCode }) ?!
                ServerError(privateMessage: "Illegal plan: \(planCode)", publicMessage: "Couldn't find the plan you selected.")
            return .form(giftForm(plan: plan), initial: GiftStep1Data(planCode: planCode), convert: GiftData.fromData, onPost: { gift in
                .catchAndDisplayError {
                    .query(gift.insert) { id in
                        .redirect(to: Route.gift(.pay(id)))
                    }
                }
            })
        
        case .pay(let giftId):
            return try showPaymentForm(giftId: giftId)

        case let .threeDSecureResponse(threeDResultToken, recurlyToken, giftId):
            return createGiftSubscription(giftId: giftId, recurlyToken: recurlyToken, threeDResultToken: threeDResultToken)
            
        case .thankYou(let id):
            return .query(Row<GiftData>.select(id)) {
                let gift = try $0 ?! ServerError(privateMessage: "gift doesn't exist: \(id.uuidString)", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
                return .write(html: giftThankYou(gift: gift.data))
            }
        
        case .redeem(let id):
            return .withSession { session in
                return .query(Row<GiftData>.select(id)) {
                    let gift = try $0 ?! ServerError(privateMessage: "gift doesn't exist: \(id.uuidString)", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
                    let plan = try Plan.gifts.first(where: { $0.plan_code == gift.data.planCode }) ?!
                        ServerError(privateMessage: "plan \(gift.data.planCode) for gift \(id.uuidString) does not exist", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
                    if session?.premiumAccess == true {
                        return try .write(html: redeemGiftAlreadySubscribed())
                    } else if let user = session?.user {
                        var g = gift
                        g.data.gifteeUserId = user.id
                        return .query(g.update()) {
                            var u = user
                            let finalStep = I.redirect(to: Route.home)
                            if !u.data.confirmedNameAndEmail {
                                u.data.name = g.data.gifteeName
                                u.data.email = g.data.gifteeEmail
                                return .query(u.update()) { _ in finalStep }
                            }
                            return finalStep // could be a special thank you page for the redeemer
                        }
                    } else {
                        return .write(html: try redeemGiftSub(gift: gift, plan: plan))
                    }
                }
            }
            
        }
    }
}
