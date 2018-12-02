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
    }, render: { data, csrf, errors in
        // todo include csrf
        let form = FormView(fields: [
            FormView.Field(id: "name", title: "Name", value: data.name, note: nil),
            FormView.Field(id: "email", title: "Email", value: data.email, note: nil)
        ], submitTitle: submitTitle, action: action, errors: errors)
        return .div(form.renderStacked(csrf: csrf))
    })
}

func registerForm(_ context: Context, couponCode: String?) -> Form<ProfileFormData> {
    return profile(submitTitle: "Create Account", action: .register(couponCode: couponCode)).wrap { node in
        LayoutConfig(context: context, contents: [
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
    
    func subscribe(context: Context, coupon: Coupon? = nil) throws -> Node {
        guard let monthly = Plan.monthly, let yearly = Plan.yearly else {
            throw RenderingError(privateMessage: "Can't find monthly or yearly plan: \([Plan.all])", publicMessage: "Something went wrong, please try again later")
        }
        
        func node(plan: Plan, title: String) -> Node {
            let amount = Double(plan.discountedPrice(coupon: coupon).usdCents) / 100
            let amountStr =  amount.isInt ? "\(Int(amount))" : String(format: "%.2f", amount) // don't use a decimal point for integer numbers
            // todo take coupon into account
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
                continueLink = Node.button(to: .reactivateSubscription, csrf: d.csrf, [.text("Reactivate Subscription")], classes: linkClasses + "c-button--ghost")
            } else {
                continueLink = Node.link(to: .accountProfile, classes: linkClasses + "c-button--ghost", ["You're already subscribed"])
            }
        } else if context.session?.user != nil {
//            print(session?.user)
            continueLink = Node.link(to: .newSubscription(couponCode: coupon?.coupon_code), classes: linkClasses, ["Proceed to payment"])
        } else {
            continueLink = Node.link(to: .login(continue: Route.newSubscription(couponCode: coupon?.coupon_code).path), classes: linkClasses, ["Sign in with Github"])
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
        return LayoutConfig(context: context, pageTitle: "Subscribe", contents: contents).layout
    }
}

func smallPrint(noTeamMemberDiscount: Bool) -> [String] {
    return
        (noTeamMemberDiscount ? ["The discount doesn’t apply to added team members."] : []) +
            [
                "Subscriptions can be cancelled at any time.",
                "All prices shown excluding VAT.",
                "VAT only applies to EU customers."
    ]
}

func newSub(context: Context, csrf: CSRFToken, coupon: Coupon?, errs: [String]) throws -> Node {
    guard let m = Plan.monthly, let y = Plan.yearly else {
        throw RenderingError(privateMessage: "No monthly or yearly plan: \(Plan.all)", publicMessage: "Something went wrong, we're on it. Please check back at a later time.")
    }
    let data = NewSubscriptionData(action: Route.createSubscription(couponCode: coupon?.coupon_code).path, public_key: env.recurlyPublicKey, plans: [
        .init(m), .init(y)
        ], payment_errors: errs, method: .post, coupon: coupon.map(NewSubscriptionData.Coupon.init), csrf: csrf)
    return LayoutConfig(context: context,  contents: [
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
