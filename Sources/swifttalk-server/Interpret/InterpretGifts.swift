//
//  InterpretGifts.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import PostgreSQL

extension Route.Gifts {
    func interpret<I: Interp>() throws -> I {
        switch self {
        case .home:
            return try I.write(giftHome(plans: Plan.gifts))
        case .new(let planCode):
            guard let plan = Plan.gifts.first(where: { $0.plan_code == planCode }) else {
                throw ServerError.init(privateMessage: "Illegal plan: \(planCode)", publicMessage: "Couldn't find the plan you selected.")
            }
            return I.form(giftForm(plan: plan), initial: GiftStep1Data(planCode: planCode), csrf: sharedCSRF, convert: Gift.fromData, onPost: { gift in
                catchAndDisplayError {
                    I.query(gift.insert) { id in
                        I.redirect(to: Route.gift(.pay(id)))
                    }
                }
            })
        case .pay(let id):
            return I.query(Row<Gift>.select(id)) { g in
                guard let gift = g else {
                    throw ServerError(privateMessage: "No such gift", publicMessage: "Something went wrong, please try again.")
                }
                let plan = try Plan.gifts.first(where: { $0.plan_code == gift.data.planCode }) ?! ServerError.init(privateMessage: "Illegal plan: \(gift.data.planCode)", publicMessage: "Couldn't find the plan you selected.")
                guard gift.data.subscriptionId == nil else {
                    throw ServerError(privateMessage: "Already paid \(gift.id)", publicMessage: "You already paid this gift.")
                }
                let f = payGiftForm(plan: plan, gift: gift.data, route: .gift(.pay(id)))
                return I.form(f, initial: .init(), csrf: sharedCSRF, validate: { _ in [] }, onPost: { (result: GiftResult) throws in
                    return I.query(UserData(email: result.gifter_email, avatarURL: "", name: "").insert) { userId in
                        let start = gift.data.sendAt > Date() ? gift.data.sendAt : nil // no start date means starting immediately
                        let cr = CreateSubscription(plan_code: plan.plan_code, currency: "USD", coupon_code: nil, starts_at: start, account: .init(account_code: userId, email: result.gifter_email, billing_info: .init(token_id: result.token)))
                        return I.onSuccess(promise: recurly.createSubscription(cr).promise, message: "Something went wrong, please try again", do: { sub_ in
                            switch sub_ {
                            case .errors(let messages):
                                log(RecurlyErrors(messages))
                                let theMessages = messages.map { ($0.field ?? "", $0.message) } + [("", "There was a problem with the payment. You have not been charged. Please try again or contact us for assistance.")]
                                let response = giftForm(plan: plan).render(GiftStep1Data(gifteeEmail: gift.data.gifteeEmail, gifteeName: gift.data.gifteeName, day: "", month: "", year: "", message: gift.data.message, planCode: plan.plan_code), sharedCSRF, theMessages)
                                return I.write(response)
                            case .success(let sub):
                                var copy = gift
                                copy.data.gifterUserId = userId
                                copy.data.subscriptionId = sub.uuid
                                copy.data.gifterEmail = result.gifter_email
                                copy.data.gifterName = result.gifter_name
                                return I.query(copy.update()) {
                                    if start != nil {
                                        let email = sendgrid.send(to: result.gifter_email, name: copy.data.gifterName ?? "", subject: "Thank you for gifting Swift Talk", text: copy.data.gifterEmailText)
                                        URLSession.shared.load(email) { result in
                                            myAssert(result != nil)
                                        }
                                    }
                                    return I.redirect(to: .gift(.thankYou(id)))
                                }
                            }
                        })
                    }
                })
            }

        case .thankYou(let id):
            return I.query(Row<Gift>.select(id)) {
                guard let gift = $0 else {
                    throw ServerError(privateMessage: "gift doesn't exist: \(id.uuidString)", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
                }
                
                return I.write(giftThankYou(gift: gift.data))
            }
        case .redeem(let id):
            return I.withSession { session in
                return I.query(Row<Gift>.select(id)) {
                    guard let gift = $0 else {
                        throw ServerError(privateMessage: "gift doesn't exist: \(id.uuidString)", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
                    }
                    guard let plan = Plan.gifts.first(where: { $0.plan_code == gift.data.planCode }) else {
                        throw ServerError(privateMessage: "plan \(gift.data.planCode) for gift \(id.uuidString) does not exist", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
                    }
                    if session?.premiumAccess == true {
                        return try I.write(redeemGiftAlreadySubscribed())
                    } else if let user = session?.user {
                        var g = gift
                        g.data.gifteeUserId = user.id
                        return I.query(g.update()) {
                            var u = user
                            let finalStep = I.redirect(to: Route.home)
                            if !u.data.confirmedNameAndEmail {
                                u.data.name = g.data.gifteeName
                                u.data.email = g.data.gifteeEmail
                                return I.query(u.update()) { _ in finalStep }
                            }
                            return finalStep // could be a special thank you page for the redeemer
                        }
                    } else {
                        return I.write(try redeemGiftSub(gift: gift, plan: plan))
                    }

                }
            }
        }
    }
}
