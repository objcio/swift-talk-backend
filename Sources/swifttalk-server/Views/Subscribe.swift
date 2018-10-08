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

struct RegisterFormData {
    var email: String
    var name: String
}

typealias ValidationError = (field: String, message: String)
func registerForm(_ session: Session) -> (form: (RegisterFormData, [ValidationError]) -> Node, parse: ([String:String]) -> RegisterFormData?) {
    func parse(_ dict: [String:String]) -> RegisterFormData? {
        guard let e = dict["email"], let n = dict["name"] else { return nil }
        return RegisterFormData(email: e, name: n)
    }
    
    func build(_ data: RegisterFormData, errors: [ValidationError]) -> Node {
        func field(id: String, description: String, value: String?) -> Node {
            return Node.fieldset(classes: "input-unit", [
                .p([
                    Node.label(classes: "input-label input-label--required", attributes: ["for": id], [.text(description)])
                ]),
                .p([
                    Node.input(classes: "text-input width-full", name: id, attributes: ["required": "required", "value": value ?? ""])
                ])
            ])
        }
        return LayoutConfig(session: nil, contents: [
            Node.header([
                Node.div(classes: "container-h pb+ pt-", [
                    Node.h1(classes: "ms4 color-blue bold", ["Create Your Account"], attributes: [:])
                ]),
            ]),
            Node.div(classes: "container", [
                Node.p(classes: "mb++ bgcolor-invalid color-white ms-1 pa radius-3 bold", [.text("\(errors)")]), // todo
                Node.div(classes: "max-width-6", [
                    Node.form(classes: "new_user", action: Route.register.path, attributes: ["id": "new_user"], [
                        // todo utf8?
                        // todo authenticity token (CSRF token)
                        Node.div(classes: "stack+", [
                            field(id: "name", description: "Name", value: data.name),
                            field(id: "email", description: "Email", value: data.email),
                            .div([
                                Node.input(classes: "c-button c-button--blue", name: "commit", type: "submit", attributes: ["value": "Create Account", "data-disable-with": "Create Account"], [])
                            ])
                        ])
                    ])
                ])
            ])
    	]).layoutForCheckout
    }
    return (build, parse)
}

extension Plan {
    static var monthly: Plan? {
        return all.first(where: { $0.plan_interval_unit == .months && $0.plan_interval_length == 1 })
    }
    static var yearly: Plan? {
        return all.first(where: { $0.plan_interval_unit == .months && $0.plan_interval_length == 12 })
    }

}
extension Array where Element == Plan {
    
    func subscribe(session: Session?, coupon: String? = nil) throws -> Node {
        guard let monthly = Plan.monthly, let yearly = Plan.yearly else {
            throw RenderingError(privateMessage: "Can't find monthly or yearly plan: \([Plan.all])", publicMessage: "Something went wrong, please try again later")
        }
        
        assert(coupon == nil) // todo
        func node(plan: Plan, title: String) -> Node {
            let amount = Double(plan.unit_amount_in_cents.usd) / 100
            let amountStr =  amount.isInt ? "\(Int(amount))" : String(format: "%.2f", amount) // don't use a decimal point for integer numbers
            // todo take coupon into account
            return .div(classes: "pb-", [
                .div(classes: "smallcaps-large mb-", ["Monthly"]),
                .span(classes: "ms7", [
                    .span(classes: "opacity-50", ["$"]),
                    .span(classes: "bold", [.text(amountStr)])
                    ])
                
                ])
        }
        let continueLink: Node
        let linkClasses: Class = "c-button c-button--big c-button--blue c-button--wide"
        if session.premiumAccess {
            continueLink = Node.link(to: .accountBilling, ["You're already subscribed"], classes: linkClasses + "c-button--ghost")
        } else if session?.user != nil {
//            print(session?.user)
            continueLink = Node.link(to: .newSubscription, ["Proceed to payment"], classes: linkClasses)
        } else {
            // todo continue to .newSubscription
            continueLink = Node.link(to: .login(continue: Route.newSubscription.path), ["Sign in with Github"], classes: linkClasses)
        }
        let contents: [Node] = [
            pageHeader(.other(header: "Subscribe to Swift Talk", blurb: nil, extraClasses: "ms5 pv---"), extraClasses: "text-center pb+++ n-mb+++"),
            .div(classes: "container pt0", [
                //                <% if @coupon.present? %>
                //                <div class="bgcolor-orange-dark text-center color-white pa- lh-125 radius-3">
                //                <span class="smallcaps inline-block">Special Deal</span>
                //                <p class="ms-1"><%= @coupon['description'] %></p>
                //                </div>
                //                <% end %>
                .div(classes: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
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
                    .ul(classes: "stack pl", smallPrint(coupon: coupon != nil).map { Node.li([.text($0)])})
                    ])
                ]),
            ]
        return LayoutConfig(session: session, pageTitle: "Subscribe", contents: contents).layout
    }
}

func smallPrint(coupon: Bool) -> [String] {
    return
        (coupon ? ["The discount doesn’t apply to added team members."] : []) +
            [
                "Subscriptions can be cancelled at any time.",
                "All prices shown excluding VAT.",
                "VAT only applies to EU customers."
    ]
}

func newSub(session: Session?, errs: [String]) throws -> Node {
    guard let m = Plan.monthly, let y = Plan.yearly else {
        throw RenderingError(privateMessage: "No monthly or yearly plan: \(Plan.all)", publicMessage: "Something went wrong, we're on it. Please check back at a later time.")
    }
    let data = NewSubscriptionData(action: Route.createSubscription.path, public_key: env["RECURLY_PUBLIC_KEY"], plans: [
        .init(m), .init(y)
    ], payment_errors: errs, method: .post, coupon: .init())
    return LayoutConfig(session: session, contents: [
        .header([
            .div(classes: "container-h pb+ pt+", [
                .h1(classes: "ms4 color-blue bold", ["Subscribe to Swift Talk"])
                ])
            ]),
        .div(classes: "container", [
            .div(classes: "react-component", attributes: [
                "data-params": json(data),
                "data-component": "NewSubscription"
                ], [])
            ])
        ]).layoutForCheckout
}

func json<A: Encodable>(_ value: A) -> String {
    let encoder = JSONEncoder()
//    encoder.keyEncodingStrategy = .convertToSnakeCase // TODO doesn't compile on Linux (?)
    return try! String(data: encoder.encode(value), encoding: .utf8)!
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
            base_price = plan.unit_amount_in_cents.usd
            interval = plan.prettyInterval
        }
    }
    struct Coupon: Codable { }
    var action: String
    var public_key: String
    var plans: [SubscriptionPlan]
    var payment_errors: [String] // TODO verify type
    var method: HTTPMethod = .post
    var coupon: Coupon
}
