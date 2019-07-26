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

func profile(submitTitle: String, action: Route) -> Form<ProfileFormData, STRequestEnvironment> {
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

func registerForm(couponCode: String?, planCode: String?, team: Bool) -> Form<ProfileFormData, STRequestEnvironment> {
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
            team ? .div(class: "smallcaps-large mt-", [.raw("Per Person<sup>*</sup>")]) : .none
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
                    } ?? .none,
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
                    } ?? .none,
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

func newSub(coupon: Coupon?, team: Bool, plans: [Plan], error: RecurlyError? = nil) throws -> Node {
    let data = SubscriptionFormData(plans: plans, selectedPlan: plans[0], coupon: coupon, error: error)
    return LayoutConfig(contents: [
        .header([
            .div(class: "container-h pb+ pt+", [
                .h1(class: "ms4 color-blue bold", ["Subscribe to Swift Talk"])
            ])
        ]),
        subscriptionForm(data, action: .subscription(.create(couponCode: coupon?.coupon_code, team: team)))
    ], includeRecurlyJS: true).layoutForCheckout
}

func threeDSecureView(threeDActionToken: String, recurlyToken: String, planId: String, couponCode: String?, team: Bool) throws -> Node {
    let placeholder = "_3dresultoken_"
    return LayoutConfig(contents: [
        .header([
            .div(class: "container-h pb+ pt+", [
                .h1(class: "ms4 color-blue bold", ["3-D Secure Authentication"])
            ]),
            .div(class: "container", attributes: ["id": "threeDSecureContainer"], [
                .p(class: "c-text mb++", ["Additional authentication is required to complete your purchase."])
            ])
        ]),
        .script(code: """
            window.addEventListener('DOMContentLoaded', (event) => {
                recurly.configure({ publicKey: '\(env.recurlyPublicKey)' });
                const container = document.querySelector('#threeDSecureContainer');
                const risk = recurly.Risk();
                const threeDSecure = risk.ThreeDSecure({ actionTokenId: '\(threeDActionToken)' });
                threeDSecure.on('error', err => {
                    container.innerHTML = `
                        <p class="c-text">Something went wrong during 3-D Secure authentication. Please retry or <a href="\(Route.subscription(.new(couponCode: couponCode, planCode: planId, team: team)).path)">use a different payment method</a>.</p>
                    `
                });
                threeDSecure.on('token', token => {
                    window.location.assign('\(Route.subscription(.threeDSecureResponse(threeDResultToken: placeholder, recurlyToken: recurlyToken, planId: planId, couponCode: couponCode, team: team)).path)'.replace('\(placeholder)', token.id));
                });
                threeDSecure.attach(container);
            });
            """),
    ], includeRecurlyJS: true).layoutForCheckout
}
