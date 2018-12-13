//
//  InterpretGifts.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import PostgreSQL

extension Route.Gifts {
    func interpret<I: SwiftTalkInterpreter>(session: Session?, context: Context, connection c: Lazy<Connection>) throws -> I {
        switch self {
        case .home:
            return try I.write(giftHome(plans: Plan.gifts, context: context))
        case .new(let planCode):
            guard let plan = Plan.gifts.first(where: { $0.plan_code == planCode }) else {
                throw ServerError.init(privateMessage: "Illegal plan: \(planCode)", publicMessage: "Couldn't find the plan you selected.")
            }
            return I.form(giftForm(plan: plan, context: context), initial: GiftStep1Data(planCode: planCode), csrf: sharedCSRF, convert: Gift.fromData, onPost: { gift in
                catchAndDisplayError {
                    let id = try c.get().execute(gift.insert)
                    return I.redirect(to: Route.gift(.pay(id)))
                }
            })
        case .pay(let id):
            guard let gift = try c.get().execute(Row<Gift>.select(id)) else {
                throw ServerError(privateMessage: "No such gift", publicMessage: "Something went wrong, please try again.")
            }
            let plan = try Plan.gifts.first(where: { $0.plan_code == gift.data.planCode }) ?! ServerError.init(privateMessage: "Illegal plan: \(gift.data.planCode)", publicMessage: "Couldn't find the plan you selected.")
            guard gift.data.subscriptionId == nil else {
                throw ServerError(privateMessage: "Already paid \(gift.id)", publicMessage: "You already paid this gift.")
            }
            let f = payGiftForm(plan: plan, gift: gift.data, context: context, route: .gift(.pay(id)))
            return I.form(f, initial: .init(), csrf: sharedCSRF, validate: { _ in [] }, onPost: { (result: GiftResult) throws in
                let userId = try c.get().execute(UserData(email: result.gifter_email, avatarURL: "", name: "").insert)
                let start = gift.data.sendAt > Date() ? gift.data.sendAt : nil // no start date means starting immediately
                let cr = CreateSubscription(plan_code: plan.plan_code, currency: "USD", coupon_code: nil, starts_at: start, account: .init(account_code: userId, email: result.gifter_email, billing_info: .init(token_id: result.token)))
                return I.onSuccess(promise: recurly.createSubscription(cr).promise, message: "Something went wrong, please try again", do: { sub_ in
                    switch sub_ {
                    case .errors(let messages):
                        log(RecurlyErrors(messages))
                        let theMessages = messages.map { ($0.field ?? "", $0.message) } + [("", "There was a problem with the payment. You have not been charged. Please try again or contact us for assistance.")]
                        let response = giftForm(plan: plan, context: context).render(GiftStep1Data(gifteeEmail: gift.data.gifteeEmail, gifteeName: gift.data.gifteeName, day: "", month: "", year: "", message: gift.data.message, planCode: plan.plan_code), sharedCSRF, theMessages)
                        return I.write(response)
                    case .success(let sub):
                        var copy = gift
                        copy.data.gifterUserId = userId
                        copy.data.subscriptionId = sub.uuid
                        copy.data.gifterEmail = result.gifter_email
                        copy.data.gifterName = result.gifter_name
                        try c.get().execute(copy.update())
                        if start != nil {
                            let email = sendgrid.send(to: result.gifter_email, name: copy.data.gifterName ?? "", subject: "Thank you for gifting Swift Talk", text: copy.data.gifterEmailText)
                            URLSession.shared.load(email) { result in
                                myAssert(result != nil)
                            }
                        }
                        return I.redirect(to: .gift(.thankYou(id)))
                    }
                })
            })
        case .thankYou(let id):
            guard let gift = try c.get().execute(Row<Gift>.select(id)) else {
                throw ServerError(privateMessage: "gift doesn't exist: \(id.uuidString)", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
            }
            
            return I.write(giftThankYou(gift: gift.data, context: context))
        case .redeem(let id):
            guard let gift = try c.get().execute(Row<Gift>.select(id)) else {
                throw ServerError(privateMessage: "gift doesn't exist: \(id.uuidString)", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
            }
            guard let plan = Plan.gifts.first(where: { $0.plan_code == gift.data.planCode }) else {
                throw ServerError(privateMessage: "plan \(gift.data.planCode) for gift \(id.uuidString) does not exist", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
            }
            if session?.premiumAccess == true {
                return try I.write(redeemGiftAlreadySubscribed(context: context))
            } else if let user = session?.user {
                var g = gift
                g.data.gifteeUserId = user.id
                try c.get().execute(g.update())
                
                var u = user
                if !u.data.confirmedNameAndEmail {
                    u.data.name = g.data.gifteeName
                    u.data.email = g.data.gifteeEmail
                    try c.get().execute(u.update())
                }
                return I.redirect(to: Route.home) // could be a special thank you page for the redeemer
            } else {
                return I.write(try redeemGiftSub(context: context, gift: gift, plan: plan))
            }
        }
    }
}
