//
//  Gifts.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 06.12.18.
//

import Foundation
import Base
import HTML1
import Database
import WebServer

extension Amount {
    var plainText: String {
        let amount = Double(usdCents) / 100
        let amountStr =  amount.isInt ? "\(Int(amount))" : String(format: "%.2f", amount)
        return "$\(amountStr)"
    }
    
    var pretty: Node {
        let amount = Double(usdCents) / 100
        let amountStr =  amount.isInt ? "\(Int(amount))" : String(format: "%.2f", amount)
        return .span(class: "ms7", [
            .span(class: "opacity-50", ["$"]),
            .span(class: "bold", [.text(amountStr)])
        ])
    }
}

func giftHome(plans: [Plan]) throws -> Node {
    func node(plan: Plan) -> Node {
        let target = Route.gift(.new(planCode: plan.plan_code))
        return .li(class: "m+|col m+|width-1/3 ph--", [
            .link(to: target, attributes: ["style": "text-decoration: none;"], [
                .div(class: "pt++ pb ph+ pattern-gradient pattern-gradient--swifttalk radius-5 text-center", [
                    .div(class: "text-center color-white", [
                        plan.unit_amount_in_cents.pretty,
                    ]),
                    .link(to: target, class: "mt+ c-button c-button--small c-button--wide", [.text(plan.prettyDuration)])
                ])
            ])
        ])
    }
    let benefits: [Node] = [
        .div(class: "text-center mt+", [
            .div(class: "color-orange", [
                .inlineSvg(class: "svg-fill-current", path: "icon-benefit-gift.svg")
            ]),
            .div([
                .h3(class: "bold color-blue mt- mb-", ["The Perfect Gift for Swift Developers"]),
                .p(class: "color-gray-50 lh-125", ["Swift Talk is a weekly live-coding video series, following two experienced developers as they discuss and implement solutions to real-world problems, while you watch. No ordinary tutorial, each episode is conversational in style, helping you follow their thoughts as they develop, and understand why we make the decisions we do."]),
            ]),
        ]),
        .div(class: "text-center mt+", [
            .div(class: "color-orange", [
                .inlineSvg(class: "svg-fill-current", path: "icon-play.svg")
            ]),
            .div([
                .h3(class: "bold color-blue mt- mb-", ["Plenty of Content"]),
                .p(class: "color-gray-50 lh-125", ["With over 130 episodes, and 20 collections, there’s plenty to watch and much to learn!"]),
                ]),
            ]),
        .div(class: "text-center mt+", [
            .div(class: "color-orange", [
                .inlineSvg(class: "svg-fill-current", path: "icon-benefit-protect.svg")
            ]),
            .div([
                .h3(class: "bold color-blue mt- mb-", ["Non-Renewing"]),
            .p(class: "color-gray-50 lh-125", ["You select the subscription period, and make a one-time payment on the day it is delivered. Gift subscriptions don’t auto-renew."]),
            ])
        ])
    ]
    let contents: [Node] = [
        pageHeader(.other(header: "Give Swift Talk as a Gift", blurb: nil, extraClasses: "ms5 pv---"), extraClasses: "text-center pb+++ n-mb+++"),
        .div(class: "container pt0", [
            .div(class: "bgcolor-white pa- radius-8 max-width-8 box-sizing-content center", [
                .ul(class: "cols m-|stack-", attributes: ["style": "padding-left:0.75em; padding-right:0.75em;"], plans.map { node(plan: $0) })
            ]),
            .div(class: "ms-1 color-gray-65 text-center pt+", [
                .p(["All prices shown excluding VAT. VAT only applies to EU customers."])
            ]),
            .div(class: "max-width-7 center", [
                .p(class: "color-gray-50 lh-125 mt++", ["Simply select which subscription you’d like to give, then tell us who to send it to and when to send it. You can write a personal message, and we’ll make sure they receive an email on the day you choose with a link to activate their gift."]),
            ] + benefits),
        ]),
    ]
    return LayoutConfig(pageTitle: "Gift a Swift Talk Subscription", contents: contents).layout
}

fileprivate let redeemheader = pageHeader(.other(header: "Redeem Your Gift", blurb: nil, extraClasses: "ms4"), extraClasses: "text-center")

func redeemGiftAlreadySubscribed() throws -> Node {
    let contents: [Node] = [
        redeemheader,
        .section(class: "container", [
            .div(class: "c-text text-center cols max-width-8 center", [
                .p(["You already have an active subscription at this moment."]),
                .p([
                    "Please email us at",
                    .link(to: URL(string: "mailto:\(email)")!, [.text(email)]),
                    "to resolve this issue."
                ]),
            ])
        ])
    ]
    return LayoutConfig(pageTitle: "Redeem Your Gift", contents: contents).layout
}

func redeemGiftSub(gift: Row<GiftData>, plan: Plan) throws -> Node {
    var message: [Node] = []
    if !gift.data.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        message = [
            .p(["They also asked us to deliver this message:"]),
            .p([.text(gift.data.message)]),
        ]
    }

    let contents: [Node] = [
        redeemheader,
        .div(class: "container pt0", [
            .div(class: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                .div(class: "text-center mt+", [
                    .div(class: "color-orange", [
                        .inlineSvg(class: "svg-fill-current", path: "icon-benefit-gift.svg")
                    ]),
                    .div(class: "c-text mt mb-", [
                        .p(["We’re pleased to say that \(gift.data.gifterName ?? "unknown") has gifted you a \(plan.prettyDuration.lowercased()) Swift Talk subscription, which starts today!"]),
                    ] + message),
                ]),
                .div([
                    .link(to: .login(.login(continue: Route.gift(.redeem(gift.id)))), class: "mt+ c-button c-button--big c-button--blue c-button--wide", ["Start By Logging In With GitHub"])
                ])
            ])
        ])
    ]
    return LayoutConfig(pageTitle: "Redeem Your Gift", contents: contents).layout
}

func giftThankYou(gift: GiftData) -> Node {
    let contents: [Node] = [
        pageHeader(.other(header: "Thank You", blurb: nil, extraClasses: "ms4"), extraClasses: "text-center"),
        .div(class: "container pt0", [
            .div(class: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                .div(class: "text-center mt+", [
                    .div(class: "color-orange", [
                        .inlineSvg(class: "svg-fill-current", path: "icon-benefit-gift.svg")
                    ]),
                    .div(class: "c-text mt mb-", [
                        .p(["Thank you for gifting Swift Talk!"]),
                        .p(["\(gift.gifteeName) will receive your gift \(gift.sendAt.isToday ? "today" : "on " + DateFormatter.fullPretty.string(from: gift.sendAt)), delivered by email to \(gift.gifteeEmail)."]),
                        gift.sendAt.isToday ? .none :.p(["Your credit card will be charged on the day of delivery."]),
                        .p([
                            "If you have any questions, feel free to contact us at",
                            .link(to: URL(string: "mailto:\(email)")!, [.text(email)]),
                            "."
                        ])
                    ])
                ])
            ])
        ])
    ]
    return LayoutConfig(pageTitle: "Thank you for gifting Swift Talk", contents: contents).layout
}


struct GiftStep1Data: Codable {
    var gifteeEmail: String = ""
    var gifteeName: String = ""
    var day: String = ""
    var month: String = ""
    var year: String = ""
    var message: String = ""
    var planCode: String
}

extension GiftStep1Data {
    init(planCode: String) {
        self.planCode = planCode
    }
}

extension GiftData {
    static func fromData(_ data: GiftStep1Data) -> Either<GiftData, [ValidationError]> {
        let day_ = Either(Int(data.day), or: [ValidationError(field: "day", message: "Day is not a number")])
        let month_ = Either(Int(data.month), or: [ValidationError(field: "month", message: "Month is not a number")])
        let year_ = Either(Int(data.year), or: [ValidationError(field: "year", message: "Year is not a number")])
        switch zip(day_, month_, year_) {
        case let .left(day, month, year):
            guard let date = Calendar.current.date(from: DateComponents(calendar: Calendar.current, timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day)) else {
                return .right([ValidationError(field: "day", message: "Invalid Date")])
            }
            let gift = GiftData(gifterEmail: nil, gifterName: nil, gifteeEmail: data.gifteeEmail, gifteeName: data.gifteeName, sendAt: date, message: data.message, gifterUserId: nil, gifteeUserId: nil, subscriptionId: nil, activated: false, planCode: data.planCode)
            let errs = gift.validate()
            return errs.isEmpty ? .left(gift) : .right(errs)
        case let .right(errs): return .right(errs)
        }
    }
}

func giftForm(submitTitle: String, plan: Plan, action: Route) -> Form<GiftStep1Data, STRequestEnvironment> {
    return Form(parse: { dict in
        guard let gifteeEmail = dict["giftee_email"],
            let message = dict["message"],
            let gifteeName = dict["giftee_name"],
            let month = dict["month"],
        	let year = dict["year"],
        	let day = dict["day"]
            else { return nil }
        return GiftStep1Data(gifteeEmail: gifteeEmail, gifteeName: gifteeName, day: day, month: month, year: year, message: message, planCode: plan.plan_code)
        
    }, render: { data, errors in
        let form = FormView(fields: [
            .text(id: "giftee_name", title: "The Recipient's Name", value: data.gifteeName),
            .text(id: "giftee_email", title: "The Recipient's Email", value: data.gifteeEmail),
            .fieldSet([
				.flex(.input(id: "day", value: data.day, type: "number", placeHolder: "DD", otherAttributes: ["min": "1", "max": "31"]), amount: 1),
                .custom(.span(class: "ph- color-gray-30 bold", ["/"])),
                .flex(.input(id: "month", value: data.month, type: "number", placeHolder: "MM", otherAttributes: ["min": "1", "max": "12"]), amount: 1),
                .custom(.span(class: "ph- color-gray-30 bold", ["/"])),
                .flex(.input(id: "year", value: data.year, type: "number", placeHolder: "YYYY", otherAttributes: ["min": "2018", "max": "2023"]), amount: 2),
            ], required: true, title: "Delivery Date", note: nil),
            .text(id: "message", required: false, title: "Your Message", value: "", multiline: 5),
            ], submitTitle: submitTitle, action: action, errors: errors)
        return .div(form.renderStacked())
    })
}

func giftForm(plan: Plan) -> Form<GiftStep1Data, STRequestEnvironment> {
    let form = giftForm(submitTitle: "Payment", plan: plan, action: .gift(.new(planCode: plan.plan_code)))
    return form.wrap { (node: Node) -> Node in
        let result: Node = LayoutConfig(contents: [
            .div(class: "container", [
                .h2(class: "color-blue bold ms2 mb", ["Your Gift 🎁"]),
                .h3(class: "color-orange bold mt- mb+", ["\(plan.prettyDuration) of Swift Talk"]),
                node
            ])
        ]).layoutForCheckout
        return result
    }
}

struct GiftResult {
    var token: String = ""
    var gifter_email: String = ""
    var gifter_name: String = ""
    
    func validate() -> [ValidationError] {
        var errs: [ValidationError] = []
        if gifter_name.count == 0 { errs.append(("gifter_name", "")) }
        if !gifter_email.isValidEmail { errs.append(("gifter_email", "")) }
        return errs
    }
}

func payGiftForm(plan: Plan, gift: GiftData, route: Route) -> Form<GiftResult, STRequestEnvironment> {
    return Form.init(parse: { dict in
        guard let d = dict["billing_info[token]"], let e = dict["gifter_email"], let n = dict["gifter_name"] else { return nil }
        return GiftResult(token: d, gifter_email: e, gifter_name: n)
    }, render: { (_, errs) -> Node in
        return .withCSRF { csrf in
            let data = SubscriptionFormData(giftPlan: plan, startDate: DateFormatter.fullPretty.string(from: gift.sendAt), errors: errs)
            return LayoutConfig(contents: [
                .header([
                    .div(class: "container-h pb+ pt+", [
                        .h1(class: "ms4 color-blue bold mb-", ["Your Details"])
                    ])
                ]),
                subscriptionForm(data, action: route)
            ], includeRecurlyJS: true).layoutForCheckout
        }
    })
}

extension GiftData {
    var gifterEmailText: String {
        let prettyDate = DateFormatter.fullPretty.string(from: sendAt)
        return """
        Hello \(gifterName ?? "unkown"),

        Thank you for gifting Swift Talk!
        
        \(gifteeName) will receive your gift on \(prettyDate), delivered by email to \(gifteeEmail).
        
        Your credit card will be charged on the day of delivery.
        
        If you have any questions, fell free to contact us at \(email).
        
        All the best,
        
        Chris and Florian
        objc.io
        """
    }
}

extension Row where Element == GiftData {
    func gifteeEmailText(duration: String) -> String {
        let url = Route.gift(.redeem(id)).url.absoluteString
        let message = data.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : """
        
        They also asked us to deliver this message:
        
        \(data.message)
        
        """
        return """
        Hello \(data.gifteeName),
        
        We’re pleased to say that \(data.gifterName ?? "unknown") has gifted you a \(duration) Swift Talk subscription, which starts today!
        \(message)
        To activate your account, just visit: \(url)
        
        We hope you enjoy watching!
        
        Chris and Florian
        objc.io
        """
    }
}
