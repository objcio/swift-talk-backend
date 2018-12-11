//
//  Gifts.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 06.12.18.
//

import Foundation

extension Array where Element == Plan {
    func gift(context: Context) throws -> Node {
        func node(plan: Plan) -> Node {
            let amount = Double(plan.unit_amount_in_cents.usdCents) / 100
            let amountStr =  amount.isInt ? "\(Int(amount))" : String(format: "%.2f", amount) // don't use a decimal point for integer numbers
            return .div(classes: "pb-", [
                .div(classes: "smallcaps-large mb-", [.text(plan.prettyDuration)]),
                .span(classes: "ms7", [
                    .span(classes: "opacity-50", ["$"]),
                    .span(classes: "bold", [.text(amountStr)])
                ])
            ])
        }
        let continueLink = Node.link(to: .gift(.new), classes: "c-button c-button--big c-button--blue c-button--wide", ["Start Gifting"])
        let benefits: [Node] = [
            Node.li(classes: "m+|col m+|width-1/2", [
                .div(classes: "color-orange", [
                    .inlineSvg(path: "icon-benefit-gift.svg", classes: "svg-fill-current")
                    ]),
                .div([
                    .h3(classes: "bold color-blue mt- mb---", [.text("The Perfect Gift for Swift Developers")]),
                    .p(classes: "color-gray-50 lh-125", [.text("This needs some copy here...")]),
                    ])
            ]),
            Node.li(classes: "m+|col m+|width-1/2", [
                .div(classes: "color-orange", [
                    .inlineSvg(path: "icon-benefit-protect.svg", classes: "svg-fill-current")
                    ]),
                .div([
                    .h3(classes: "bold color-blue mt- mb---", [.text("Non-Renewing")]),
                    .p(classes: "color-gray-50 lh-125", [.text("You choose the duration of the subscription up front and make a one-time payment. Gift subscriptions don't auto-renew.")]),
                ])
            ])
        ]
        let contents: [Node] = [
            pageHeader(.other(header: "Gift a Swift Talk Subscription", blurb: nil, extraClasses: "ms5 pv---"), extraClasses: "text-center pb+++ n-mb+++"),
            .div(classes: "container pt0", [
                .div(classes: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                    .div(classes: "pattern-gradient pattern-gradient--swifttalk pv++ ph+ radius-5", [
                        .div(classes: "flex items-center justify-around text-center color-white", self.map { node(plan: $0) })
                    ]),
                    .div([
                        continueLink
                    ])
                ]),
                Node.ul(classes: "lh-110 text-center cols max-width-9 center mb- pv++ m-|stack+", benefits),
                .div(classes: "ms-1 color-gray-65 text-center pt+", [
                    .ul(classes: "stack pl", smallPrint().map { Node.li([.text($0)])})
                ])
            ]),
        ]
        return LayoutConfig(context: context, pageTitle: "Gift a Swift Talk Subscription", contents: contents).layout
    }
}

fileprivate func smallPrint() -> [String] {
    return [
        "All prices shown excluding VAT.",
        "VAT only applies to EU customers."
    ]
}

fileprivate let redeemheader = pageHeader(.other(header: "Redeem Your Gift Subscription", blurb: nil, extraClasses: "ms5 pv---"), extraClasses: "text-center pb")

func redeemGiftAlreadySubscribed(context: Context) throws -> Node {
    let contents: [Node] = [
        redeemheader,
        .section(classes: "container", [
            .div(classes: "lh-125 color-gray-30 text-center cols max-width-8 center pv++", [
                .p([.text("You already have an active subscription at this moment.")]),
                .p([
                    .text("Please email us at"),
                    .link(to: URL(string: "mailto:\(email)")!, [.text(email)]),
                    .text("to resolve this issue.")
                ]),
            ])
        ])
    ]
    return LayoutConfig(context: context, pageTitle: "Redeem Your Gift Subscription", contents: contents).layout
}

func redeemGiftSub(context: Context, giftId: UUID) throws -> Node {
    let contents: [Node] = [
        redeemheader,
        .div(classes: "container pt0", [
            .div(classes: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                .div([
                    Node.link(to: .login(continue: Route.gift(.redeem(giftId)).path), classes: "c-button c-button--big c-button--blue c-button--wide", ["Login with GitHub"])
                ])
            ])
        ])
    ]
    return LayoutConfig(context: context, pageTitle: "Redeem Your Gift Subscription", contents: contents).layout
}


struct GiftStep1Data: Codable {
    var gifteeEmail: String = ""
    var gifteeName: String = ""
    var day: String = ""
    var month: String = ""
    var year: String = ""
    var message: String = ""
}


extension Gift {
    static func fromData(_ data: GiftStep1Data) -> Either<Gift, [ValidationError]> {
        let day_ = Either(Int(data.day), or: [ValidationError(field: "day", message: "Day is not a number")])
        let month_ = Either(Int(data.month), or: [ValidationError(field: "month", message: "Month is not a number")])
        let year_ = Either(Int(data.year), or: [ValidationError(field: "year", message: "Year is not a number")])
        switch zip(day_, month_, year_) {
        case let .left(day, month, year):
            guard let date = Calendar.current.date(from: DateComponents(calendar: Calendar.current, timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day)) else {
                return .right([ValidationError(field: "day", message: "Invalid Date")])
            }
            return .left(Gift(gifterEmail: nil, gifterName: nil, gifteeEmail: data.gifteeEmail, gifteeName: data.gifteeName, sendAt: date, message: data.message, gifterUserId: nil, gifteeUserId: nil, subscriptionId: nil, activated: false))
        case let .right(errs): return .right(errs)
        }
    }
}

func giftForm(submitTitle: String, action: Route) -> Form<GiftStep1Data> {
    return Form(parse: { dict in
        guard let gifteeEmail = dict["giftee_email"],
            let message = dict["message"],
            let gifteeName = dict["giftee_name"],
            let month = dict["month"],
        	let year = dict["year"],
        	let day = dict["day"]
            else { return nil }
        return GiftStep1Data(gifteeEmail: gifteeEmail, gifteeName: gifteeName, day: day, month: month, year: year, message: message)
        
    }, render: { data, csrf, errors in
        let form = FormView(fields: [
            .text(id: "giftee_name", title: "The Recipients' Name", value: data.gifteeName),
            .text(id: "giftee_email", title: "The Recipients' Email", value: data.gifteeEmail),
            .fieldSet([
				.flex(.input(id: "day", value: data.day, type: "number", placeHolder: "DD", otherAttributes: ["min": "1", "max": "31"]), amount: 1),
                .custom(Node.span(classes: "ph- color-gray-30 bold", [.text("/")])),
                .flex(.input(id: "month", value: data.month, type: "number", placeHolder: "MM", otherAttributes: ["min": "1", "max": "12"]), amount: 1),
                .custom(Node.span(classes: "ph- color-gray-30 bold", [.text("/")])),
                .flex(.input(id: "year", value: data.year, type: "number", placeHolder: "YYYY", otherAttributes: ["min": "2018", "max": "2023"]), amount: 2),
            ], required: true, title: "Delivery Date", note: nil),
            .text(id: "message", required: false, title: "Your Message", value: "", multiline: 5),
            ], submitTitle: submitTitle, action: action, errors: errors)
        return .div(form.renderStacked(csrf: csrf))
    })
}

func giftForm(context: Context) -> Form<GiftStep1Data> {
    let form = giftForm(submitTitle: "Step 2: Plan and Payment", action: .gift(.new))
    return form.wrap { (node: Node) -> Node in
        let result: Node = LayoutConfig(context: context, contents: [
            .div(classes: "container", [
                Node.h2(classes: "color-blue bold ms2 mb", [.text("New Gift Subscription (Step 1/2)")]),
                node
            ])
        ]).layoutForCheckout
        return result
    }
}

struct GiftResult {
    var token: String = ""
    var plan_id: String = ""
    var gifter_email: String = ""
}

func payGiftForm(context: Context, route: Route) -> Form<GiftResult> {
    return Form.init(parse: { dict in
        dump(dict)
        guard let d = dict["billing_info[token]"], let p = dict["plan_id"], let e = dict["gifter_email"] else { return nil }
        return GiftResult(token: d, plan_id: p, gifter_email: e)
    }, render: { (_, csrf, errs) -> Node in
        let data = NewGiftSubscriptionData(action: route.path, public_key: env.recurlyPublicKey, plans: Plan.gifts.map { .init($0) }, payment_errors: errs.map { "\($0.field): \($0.message)" }, method: .post, csrf: csrf)
        return LayoutConfig(context: context,  contents: [
            .header([
                .div(classes: "container-h pb+ pt+", [
                    .h1(classes: "ms4 color-blue bold", ["Complete Your Purchase"])
                    ])
                ]),
            .div(classes: "container", [
                ReactComponent.newGiftSubscription.build(data)
                ])
		], includeRecurlyJS: true).layoutForCheckout
    })
}

extension Gift {
    var gifterEmailText: String {
        let prettyDate = DateFormatter.fullPretty.string(from: sendAt)
        return """
        Hello \(gifterName),
        
        Thank you for gifting Swift Talk. The gift will be sent to \(gifteeName) (\(gifteeEmail)) on \(prettyDate).
        
        Your credit card is not charged yet, but will be charged on \(prettyDate).
        
        Thanks,
        objc.io
        """
    }
}

extension Row where Element == Gift {
    func gifteeEmailText(duration: String) -> String {
        let url = Route.gift(.redeem(id)).url.absoluteString
        
        let theMessage: String = data.message.isEmpty ? "" : ("Here is their message: \n\n" + data.message)
        
        return """
        Hello \(data.gifteeName),
        
        \(data.gifterName) has sent you a gift Swift Talk subscription for \(duration). \(theMessage)
        
        Your subscription start today, and you can activate your account at:
        
        \(url)
        
        Thanks,
        objc.io
        """
    }
}
