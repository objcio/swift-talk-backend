//
//  Subscribe.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import Base
import HTML
import WebServer


let subscriptionBenefits: [(icon: String, name: String, description: String)] = [
    ("icon-benefit-unlock.svg", "Watch All Episodes", "A new episode every week"),
    ("icon-benefit-download.svg", "Download Episodes", "Take Swift Talk with you when you're offline"),
    ("icon-benefit-support.svg", "Support Us", "With your help we can keep producing new episodes"),
]


func benefits(_ items: [(icon: String, name: String, description: String)]) -> Node {
    return .ul(class: "lh-110 text-center cols max-width-9 center mb- pv++ m-|stack+", items.map { b in
        .li(class: "m+|col m+|width-1/3", [
            .div(class: "color-orange", [
                .inlineSvg(class: "svg-fill-current", path: b.icon)
            ]),
            .div([
                .h3(class: "bold color-blue mt- mb---", [.text(b.name)]),
                .p(class: "color-gray-50 lh-125", [.text(b.description)])
            ])
        ])
    })
}

struct ProfileFormData {
    var email: String
    var name: String
}

func profile(submitTitle: String, action: Route) -> Form<ProfileFormData, Node> {
    return Form(parse: { dict in
        guard let e = dict["email"], let n = dict["name"] else { return nil }
        return ProfileFormData(email: e, name: n)
    }, render: { data, errors in
        let form = FormView(fields: [
            .text(id: "name", title: "Name", value: data.name, note: nil),
            .text(id: "email", title: "Email", value: data.email, note: nil)
        ], submitTitle: submitTitle, action: action, errors: errors)
        let rendered = form.renderStacked()
        return Node.div(class: nil, rendered)
    })
}

func registerForm(couponCode: String?, planCode: String?, team: Bool) -> Form<ProfileFormData, Node> {
    return profile(submitTitle: "Create Account", action: .account(.register(couponCode: couponCode, planCode: planCode, team: team))).wrap { node in
        LayoutConfig(contents: [
            .header([
                .div(class: "container-h pb+ pt-", [
                    .h1(class: "ms4 color-blue bold", ["Create Your Account"])
                ]),
            ]),
            .div(class: "container", [node])
        ]).layoutForCheckout
    }
}

fileprivate extension Plan {
    func priceBox(coupon: Coupon?, team: Bool = false) -> Node {
        let basePriceKey: KeyPath<Plan, Amount> = team ? \.teamMemberPrice : \.unit_amount_in_cents
        let price = discountedPrice(basePrice: basePriceKey, coupon: coupon)
        return .div([
            .div(class: "smallcaps-large mb-", [.text(prettyInterval)]),
            price.pretty,
            team ? .div(class: "smallcaps-large mt-", [Node.raw("Per Person<sup>*</sup>")]) : .none()
        ])
    }
}

fileprivate func continueLink(to route: Route, title: String, extraClasses: Class? = nil) -> Node {
    let linkClasses: Class = "c-button c-button--big c-button--blue c-button--wide"
    return .link(to: route, class: linkClasses + (extraClasses ?? ""), [.text(title)])
}

fileprivate func continueLink(session: Session?, coupon: Coupon?, team: Bool) -> Node {
    if session.premiumAccess {
        if let d = session?.user.data, d.canceled {
            return continueLink(to: .account(.billing), title: "Reactivate Subscription", extraClasses: "c-button--ghost")
        } else {
            return continueLink(to: .account(.billing), title: "You're already subscribed", extraClasses: "c-button--ghost")
        }
    } else if session?.user != nil {
        return continueLink(to: .subscription(.new(couponCode: coupon?.coupon_code, planCode: nil, team: team)), title: "Proceed to payment")
    } else {
        return continueLink(to: .login(.login(continue: Route.subscription(.new(couponCode: coupon?.coupon_code, planCode: nil, team: team)))), title: "Sign in with Github")
    }
}

func renderSubscribe(monthly: Plan, yearly: Plan, coupon: Coupon? = nil) -> Node {
    return .withSession { session in
        let contents: [Node] = [
            pageHeader(.other(header: "Subscribe to Swift Talk", blurb: nil, extraClasses: "ms5 pv---"), extraClasses: "text-center pb+++ n-mb+++"),
            .div(class: "container pt0", [
                .div(class: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                    coupon.map { c in
                        .div(class: "bgcolor-orange-dark text-center color-white pa- lh-125 radius-3", [
                            .span(class: "smallcaps inline-block", ["Special Deal"]),
                            .p(class: "ms-1", [.text(c.description)])
                        ])
                    } ?? .none(),
                    .div(class: "pattern-gradient pattern-gradient--swifttalk pv++ ph+ radius-5", [
                        .div(class: "flex items-center justify-around text-center color-white", [
                            monthly.priceBox(coupon: coupon),
                            yearly.priceBox(coupon: coupon),
                        ])
                    ]),
                    .div([
                        continueLink(session: session, coupon: coupon, team: false)
                    ])
                ]),
                benefits(subscriptionBenefits),
                .ul(class: "text-center max-width-7 center pt++ pb++", [
                    .div(class: "color-orange", [
                        .inlineSvg(class: "svg-fill-current", path: "icon-benefit-team.svg")
                    ]),
                    .div(class: "mb+", [
                        .link(to: .signup(.subscribeTeam), class: "no-decoration", [.h3(class: "bold color-blue ms3 mt-- mb-", ["Team Subscriptions"])]),
                        .p(class: "color-gray-50 lh-125", [
                            "Our team subscription includes a 30% discount and comes with a central account that lets you manage billing and access for your entire team.",
                            .link(to: .signup(.subscribeTeam), class: "no-decoration color-blue", ["Learn more..."])
                        ])
                    ])
                ]),
                .div(class: "ms-1 color-gray-65 lh-110 text-center pt+", [
                    smallPrint([
                        "All prices shown excluding VAT (only applies to EU customers).",
                    ])
                ])
            ]),
        ]
        return LayoutConfig(pageTitle: "Subscribe", contents: contents).layout
    }
}

func renderSubscribeTeam(monthly: Plan, yearly: Plan, coupon: Coupon? = nil) -> Node {
    return .withSession { session in
        let contents: [Node] = [
            pageHeader(.other(header: "Swift Talk Team Subscription", blurb: nil, extraClasses: "ms5 pv---"), extraClasses: "text-center pb+++ n-mb+++"),
            .div(class: "container pt0", [
                .div(class: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                    coupon.map { c in
                        .div(class: "bgcolor-orange-dark text-center color-white pa- lh-125 radius-3", [
                            .span(class: "smallcaps inline-block", ["Special Deal"]),
                            .p(class: "ms-1", [.text(c.description)])
                        ])
                    } ?? .none(),
                    .div(class: "pattern-gradient pattern-gradient--swifttalk pv++ ph+ radius-5", [
                        .div(class: "flex items-center justify-around text-center color-white", [
                            monthly.priceBox(coupon: coupon, team: true),
                            yearly.priceBox(coupon: coupon, team: true),
                        ])
                    ]),
                    .div([
                        continueLink(session: session, coupon: coupon, team: true)
                    ])
                ]),
                benefits([
                    ("icon-benefit-unlock.svg", "Watch All Episodes", "A new episode every week"),
                    ("icon-benefit-manager.svg", "Team Manager Account", "A central account to manage billing and team members"),
                    ("icon-benefit-download.svg", "Download Episodes", "Take Swift Talk with you when you're offline"),
                ]),
                .ul(class: "text-center max-width-7 center pv+", [
                    .div(class: "mb+", [
                        .h3(class: "bold color-blue ms1 mt-- mb-", ["Enterprise Subscriptions"]),
                        .p(class: "color-gray-50 lh-125", [
                            "Please ",
                            .link(to: URL(string: "mailto:\(email)")!, class: "no-decoration color-blue", ["get in touch"]),
                            " for teams with more than 30 members."
                            ])
                        ])
                    ]),
                .div(class: "ms-1 color-gray-65 lh-110 text-center center pt+ max-width-8", [
                    smallPrint([
                        .span([.raw("<sup>*</sup>"), "Prices apply from the 2nd team member. The first team member is included in the subscription base price, \(monthly.discountedPrice(coupon: coupon).plainText)/month or \(yearly.discountedPrice(coupon: coupon).plainText)/year"]),
                        "All prices shown excluding VAT (only applies to EU customers).",
                    ])
                ])
            ]),
        ]
        return LayoutConfig(pageTitle: "Subscribe", contents: contents).layout
    }
}

fileprivate func smallPrint(_ lines: [Node]) -> Node {
    return .ul(class: "stack pl", lines.map { .li([$0])})
}

func newSub(coupon: Coupon?, team: Bool, plans: [Plan], errs: [String]) throws -> Node {
    return .withCSRF { csrf in
        let data = NewSubscriptionData(action: Route.subscription(.create(couponCode: coupon?.coupon_code, team: team)).path, public_key: env.recurlyPublicKey, plans: plans.map { .init($0) }, payment_errors: errs, method: .post, coupon: coupon.map(NewSubscriptionData.Coupon.init), csrf: csrf)
        return LayoutConfig(contents: [
            .header([
                .div(class: "container-h pb+ pt+", [
                    .h1(class: "ms4 color-blue bold", ["Subscribe to Swift Talk"])
                ])
            ]),
            .div(class: "container", [
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
