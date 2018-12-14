//
//  Subscribe.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation


let benefits: [(icon: String, name: String, description: String)] = [
    ("icon-benefit-unlock.svg", "Watch All Episodes", "New subscriber-only episodes every two weeks"), // TODO
    ("icon-benefit-team.svg", "Invite Your Team", "Sign up additional team members at \(teamDiscount)% discount"),
    ("icon-benefit-support.svg", "Support Us", "Ensure the continuous production of new episodes"),
]

func newSubscriptionBanner() -> Node {
    return Node.ul(classes: "lh-110 text-center cols max-width-9 center mb- pv++ m-|stack+", benefits.map { b in
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

func registerForm(couponCode: String?) -> Form<ProfileFormData> {
    return profile(submitTitle: "Create Account", action: .account(.register(couponCode: couponCode))).wrap { node in
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

extension Array where Element == Plan {    
    func subscribe(monthly: Plan, yearly: Plan, coupon: Coupon? = nil) -> Node {
        return .withContext { context in
            func node(plan: Plan, title: String) -> Node {
                let amount = Double(plan.discountedPrice(coupon: coupon).usdCents) / 100
                let amountStr =  amount.isInt ? "\(Int(amount))" : String(format: "%.2f", amount) // don't use a decimal point for integer numbers
                return .div(classes: "pb-", [
                    .div(classes: "smallcaps-large mb-", [.text(plan.prettyInterval)]),
                    .span(classes: "ms7", [
                        .span(classes: "opacity-50", ["$"]),
                        .span(classes: "bold", [.text(amountStr)])
                        ])
                    
                    ])
            }
            let continueLink: Node
            let linkClasses: Class = "c-button c-button--big c-button--blue c-button--wide"
            if context.session.premiumAccess {
                if let d = context.session?.user.data, d.canceled {
                    continueLink = Node.button(to: .subscription(.reactivate), [.text("Reactivate Subscription")], classes: linkClasses + "c-button--ghost")
                } else {
                    continueLink = Node.link(to: .account(.profile), classes: linkClasses + "c-button--ghost", ["You're already subscribed"])
                }
            } else if context.session?.user != nil {
                continueLink = Node.link(to: .subscription(.new(couponCode: coupon?.coupon_code)), classes: linkClasses, ["Proceed to payment"])
            } else {
                continueLink = Node.link(to: .login(continue: Route.subscription(.new(couponCode: coupon?.coupon_code)).path), classes: linkClasses, ["Sign in with Github"])
            }
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
                                node(plan: monthly, title: "Monthly"),
                                node(plan: yearly, title: "Yearly"),
                                ])
                            ]),
                        .div([
                            continueLink
                            ])
                        
                        ]),
                    newSubscriptionBanner(),
                    .div(classes: "ms-1 color-gray-65 text-center pt+", [
                        .ul(classes: "stack pl", smallPrint(noTeamMemberDiscount: coupon != nil && !coupon!.applies_to_non_plan_charges).map { Node.li([.text($0)])})
                        ])
                    ]),
                ]
            return LayoutConfig(pageTitle: "Subscribe", contents: contents).layout
        }
    }
}

fileprivate func smallPrint(noTeamMemberDiscount: Bool) -> [String] {
    return
        (noTeamMemberDiscount ? ["The discount doesn’t apply to added team members."] : []) +
            [
                "Subscriptions can be cancelled at any time.",
                "All prices shown excluding VAT.",
                "VAT only applies to EU customers."
    ]
}

func newSub(csrf: CSRFToken, coupon: Coupon?, errs: [String]) throws -> Node {
    guard let m = Plan.monthly, let y = Plan.yearly else {
        throw ServerError(privateMessage: "No monthly or yearly plan: \(Plan.all)", publicMessage: "Something went wrong, we're on it. Please check back at a later time.")
    }
    let data = NewSubscriptionData(action: Route.subscription(.create(couponCode: coupon?.coupon_code)).path, public_key: env.recurlyPublicKey, plans: [
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
