//
//  Subscribe.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation


let subscriptionBenefits: [(icon: String, name: String, description: String)] = [
    ("icon-benefit-unlock.svg", "Watch All Episodes", "A new episode every week"),
    ("icon-benefit-download.svg", "Download Episodes", "Take Swift Talk with you when you're offline"),
    ("icon-benefit-support.svg", "Support Us", "Ensure the continuous production of new episodes"),
]


func benefits(_ items: [(icon: String, name: String, description: String)]) -> Node {
    return Node.ul(classes: "lh-110 text-center cols max-width-9 center mb- pv++ m-|stack+", items.map { b in
        Node.li(classes: "m+|col m+|width-1/3", [
            .div(classes: "color-orange", [
                .inlineSvg(path: b.icon, classes: "svg-fill-current")
                ]),
            .div([
                .h3(classes: "bold color-blue mt- mb---", [.text(b.name)]),
                .p(classes: "color-gray-50 lh-125", [.text(b.description)])
            ])
        ])
    })
}

struct ProfileFormData {
    var email: String
    var name: String
}

func profile(submitTitle: String, action: Route) -> Form<ProfileFormData> {
    return Form(parse: { dict in
        guard let e = dict["email"], let n = dict["name"] else { return nil }
        return ProfileFormData(email: e, name: n)
    }, render: { data, errors in
        let form = FormView(fields: [
            .text(id: "name", title: "Name", value: data.name, note: nil),
            .text(id: "email", title: "Email", value: data.email, note: nil)
        ], submitTitle: submitTitle, action: action, errors: errors)
        return .div(form.renderStacked())
    })
}

func registerForm(couponCode: String?, team: Bool) -> Form<ProfileFormData> {
    return profile(submitTitle: "Create Account", action: .account(.register(couponCode: couponCode, team: team))).wrap { node in
        LayoutConfig(contents: [
            Node.header([
                Node.div(classes: "container-h pb+ pt-", [
                    Node.h1(classes: "ms4 color-blue bold", ["Create Your Account"])
                ]),
            ]),
            Node.div(classes: "container", [node])
        ]).layoutForCheckout
    }
}

fileprivate extension Amount {
    var pretty: String {
        let amount = Double(usdCents) / 100
        return amount.isInt ? "\(Int(amount))" : String(format: "%.2f", amount) // don't use a decimal point for integer numbers
    }
}

fileprivate extension Plan {
    func priceBox(coupon: Coupon?, team: Bool = false) -> Node {
        let basePriceKey: KeyPath<Plan, Amount> = team ? \.teamMemberPrice : \.unit_amount_in_cents
        let price = discountedPrice(basePrice: basePriceKey, coupon: coupon)
        return .div([
            .div(classes: "smallcaps-large mb-", [.text(prettyInterval)]),
            .span(classes: "ms7", [
                .span(classes: "opacity-50", ["$"]),
                .span(classes: "bold", [.text(price.pretty)])
            ]),
            team ? .div(classes: "smallcaps-large mt-", [.raw("Per Person<sup>*</sup>")]) : .none
        ])
    }
}

fileprivate func continueLink(to route: Route, title: String, extraClasses: Class? = nil) -> Node {
    let linkClasses: Class = "c-button c-button--big c-button--blue c-button--wide"
    return Node.link(to: route, classes: linkClasses + (extraClasses ?? ""), [.text(title)])
}

fileprivate func continueLink(context: Context, coupon: Coupon?, team: Bool) -> Node {
    if context.session.premiumAccess {
        if let d = context.session?.user.data, d.canceled {
            return continueLink(to: .account(.billing), title: "Reactivate Subscription", extraClasses: "c-button--ghost")
        } else {
            return continueLink(to: .account(.billing), title: "You're already subscribed", extraClasses: "c-button--ghost")
        }
    } else if context.session?.user != nil {
        return continueLink(to: .subscription(.new(couponCode: coupon?.coupon_code, team: team)), title: "Proceed to payment")
    } else {
        return continueLink(to: .login(continue: Route.subscription(.new(couponCode: coupon?.coupon_code, team: team))), title: "Sign in with Github")
    }
}

func renderSubscribe(monthly: Plan, yearly: Plan, coupon: Coupon? = nil) -> Node {
    return .withContext { context in
        let contents: [Node] = [
            pageHeader(.other(header: "Subscribe to Swift Talk", blurb: nil, extraClasses: "ms5 pv---"), extraClasses: "text-center pb+++ n-mb+++"),
            .div(classes: "container pt0", [
                .div(classes: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                    coupon.map { c in
                        Node.div(classes: "bgcolor-orange-dark text-center color-white pa- lh-125 radius-3", [
                            Node.span(classes: "smallcaps inline-block", [.text("Special Deal")]),
                            Node.p(classes: "ms-1", [.text(c.description)])
                        ])
                    } ?? .none,
                    .div(classes: "pattern-gradient pattern-gradient--swifttalk pv++ ph+ radius-5", [
                        .div(classes: "flex items-center justify-around text-center color-white", [
                            monthly.priceBox(coupon: coupon),
                            yearly.priceBox(coupon: coupon),
                        ])
                    ]),
                    .div([
                        continueLink(context: context, coupon: coupon, team: false)
                    ])
                ]),
                benefits(subscriptionBenefits),
                Node.ul(classes: "text-center max-width-7 center pt pb++", [
                    .div(classes: "color-orange", [
                        .inlineSvg(path: "icon-benefit-team.svg", classes: "svg-fill-current")
                    ]),
                    .div(classes: "mb+", [
                        .h3(classes: "bold color-blue mt- mb---", ["Looking for a subscription for your whole team?"]),
                        .p(classes: "color-gray-50 lh-125", ["Our team subscription offers a 30% discount and comes with a separate team manager account to manage billing and access for your entire team."])
                    ]),
                    continueLink(to: .subscribeTeam, title: "Explore Team Subscriptions")
                ]),
                .div(classes: "ms-1 color-gray-65 text-center pt+", [
                    smallPrint([
                        "All prices shown excluding VAT (only applies to EU customers).",
                        "Subscriptions can be cancelled at any time.",
                    ])
                ])
            ]),
        ]
        return LayoutConfig(pageTitle: "Subscribe", contents: contents).layout
    }
}

func renderSubscribeTeam(monthly: Plan, yearly: Plan, coupon: Coupon? = nil) -> Node {
    return .withContext { context in
        let contents: [Node] = [
            pageHeader(.other(header: "Swift Talk Team Subscription", blurb: nil, extraClasses: "ms5 pv---"), extraClasses: "text-center pb+++ n-mb+++"),
            .div(classes: "container pt0", [
                .div(classes: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                    coupon.map { c in
                        Node.div(classes: "bgcolor-orange-dark text-center color-white pa- lh-125 radius-3", [
                            Node.span(classes: "smallcaps inline-block", [.text("Special Deal")]),
                            Node.p(classes: "ms-1", [.text(c.description)])
                        ])
                    } ?? .none,
                    .div(classes: "pattern-gradient pattern-gradient--swifttalk pv++ ph+ radius-5", [
                        .div(classes: "flex items-center justify-around text-center color-white", [
                            monthly.priceBox(coupon: coupon, team: true),
                            yearly.priceBox(coupon: coupon, team: true),
                        ])
                    ]),
                    .div([
                        continueLink(context: context, coupon: coupon, team: true)
                    ])
                ]),
                benefits([
                    ("icon-benefit-unlock.svg", "Watch All Episodes", "A new episode every week"),
                    ("icon-benefit-manager.svg", "Team Manager Account", "A central account to manage billing and team members"),
                    ("icon-benefit-download.svg", "Download Episodes", "Take Swift Talk with you when you're offline"),
                ]),
                .div(classes: "ms-1 color-gray-65 text-center center pt+ max-width-8", [
                    smallPrint([
                        .span([.raw("<sup>*</sup>"), .text("Prices apply from the 2nd team member. The first team member is included in the subscription base price, $\(monthly.discountedPrice(coupon: coupon).pretty)/month or $\(yearly.discountedPrice(coupon: coupon).pretty)/year")]),
                        "All prices shown excluding VAT (only applies to EU customers).",
                        "Subscriptions can be cancelled at any time.",
                    ])
                ])
            ]),
        ]
        return LayoutConfig(pageTitle: "Subscribe", contents: contents).layout
    }
}

fileprivate func smallPrint(_ lines: [Node]) -> Node {
    return Node.ul(classes: "stack pl", lines.map { Node.li([$0])})
}

func newSub(coupon: Coupon?, team: Bool, errs: [String]) throws -> Node {
    guard let m = Plan.monthly, let y = Plan.yearly else {
        throw ServerError(privateMessage: "No monthly or yearly plan: \(Plan.all)", publicMessage: "Something went wrong, we're on it. Please check back at a later time.")
    }
    return Node.withCSRF { csrf in        
        let data = NewSubscriptionData(action: Route.subscription(.create(couponCode: coupon?.coupon_code, team: team)).path, public_key: env.recurlyPublicKey, plans: [
            .init(m), .init(y)
            ], payment_errors: errs, method: .post, coupon: coupon.map(NewSubscriptionData.Coupon.init), csrf: csrf)
        return LayoutConfig(contents: [
            .header([
                .div(classes: "container-h pb+ pt+", [
                    .h1(classes: "ms4 color-blue bold", ["Subscribe to Swift Talk"])
                ])
            ]),
            .div(classes: "container", [
                ReactComponent.newSubscription.build(data)
            ])
        ], includeRecurlyJS: true).layoutForCheckout
    }
}

extension ReactComponent where A == NewSubscriptionData {
    static let newSubscription: ReactComponent<A> = ReactComponent(name: "NewSubscription")
}


extension ReactComponent where A == NewGiftSubscriptionData {
    static let newGiftSubscription: ReactComponent<A> = ReactComponent(name: "NewGiftSubscription")
}

extension Plan {
    var prettyInterval: String {
        switch  plan_interval_unit {
        case .months where plan_interval_length == 1:
            return "monthly"
        case .months where plan_interval_length == 12:
            return "yearly"
        default:
            return "every \(plan_interval_length) \(plan_interval_unit.rawValue)"
        }
    }
    
    var prettyDuration: String {
        switch  plan_interval_unit {
        case .days:
            return "\(plan_interval_length) Days"
        case .months:
            if plan_interval_length == 12 {
                return "One Year"
            } else if plan_interval_length == 1 {
            	return "1 Month"
            } else {
                return "\(plan_interval_length) Months"
            }
        }
    }
}

struct NewGiftSubscriptionData: Codable {
    struct SubscriptionPlan: Codable {
        var id: String
        var base_price: Int
        var interval: String
        
        init(_ plan: Plan) {
            id = plan.plan_code
            base_price = plan.unit_amount_in_cents.usdCents
            interval = plan.prettyDuration
            // todo make sure we don't renew
//            myAssert(plan.total_billing_cycles == 1) // we don't support other plans yet
        }
    }
    var action: String
    var public_key: String
    var plan: SubscriptionPlan
    var start_date: String
    var payment_errors: [String] // TODO verify type
    var csrf: String
    var method: HTTPMethod = .post
}

struct NewSubscriptionData: Codable {
    struct SubscriptionPlan: Codable {
        var id: String
        var base_price: Int
        var interval: String
        
        init(_ plan: Plan) {
            id = plan.plan_code
            base_price = plan.unit_amount_in_cents.usdCents
            interval = plan.prettyInterval
        }
    }
    struct Coupon: Codable {
        var code: String
        var discount_type: String
        var discount_percent: Int?
        var description: String
        var discount_in_cents: Amount?
        var free_trial_amount: Int?
        var free_trial_unit: TemporalUnit?

    }
    var action: String
    var public_key: String
    var plans: [SubscriptionPlan]
    var payment_errors: [String] // TODO verify type
    var method: HTTPMethod = .post
    var coupon: Coupon?
    var csrf: CSRFToken
}

extension NewSubscriptionData.Coupon {
    init(_ coupon: Coupon) {
        code = coupon.coupon_code
        discount_type = coupon.discount_type.rawValue
        description = coupon.description
        discount_percent = coupon.discount_percent
        discount_in_cents = coupon.discount_in_cents
        free_trial_amount = coupon.free_trial_amount
        free_trial_unit = coupon.free_trial_unit
    }
}
