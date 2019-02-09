//
//  Account.swift
//  Bits
//
//  Created by Chris Eidhof on 06.11.18.
//

import Foundation
import Base
import HTML
import Database
import WebServer


fileprivate let accountHeader = pageHeader(.other(header: "Account", blurb: nil, extraClasses: "ms4"))

func accountContainer(content: Node, forRoute: Route) -> Node {
    return .withSession { session in
        var items: [(Route, title: String)] = [
            (Route.account(.profile), title: "Profile"),
            (Route.account(.billing), title: "Billing"),
            (Route.account(.logout), title: "Logout"),
        ]
        if session?.selfPremiumAccess == true || session?.user.data.role == .teamManager {
            items.insert((Route.account(.teamMembers), title: "Team Members"), at: 2)
        }
        return .div(classes: "container pb0", [
            .div(classes: "cols m-|stack++", [
                .div(classes: "col width-full m+|width-1/4", [
                    .div(classes: "submenu", items.map { item in
                        .link(to: item.0, classes: "submenu__item" + (item.0 == forRoute ? "is-active" : ""), attributes: [:], [.text(item.title)])
                    })
                ]),
                .div(classes: "col width-full m+|width-3/4", [content])
            ])
        ])
    }
}

// Icon from font-awesome
func faIcon(name: String, classes: Class = "") -> Node {
    let iconName = Class(stringLiteral: "fa-" + name)
    return .i(classes: "fa" + iconName + classes)
}

extension Invoice.State {
    var icon: (String, Class) {
        switch self {
        case .pending:
            return ("refresh", "color-gray-50 fa-spin")
        case .paid:
            return ("check", "color-blue")
        case .failed:
            return ("times", "color-invalid")
        case .past_due:
            return ("clock-o", "color-invalid")
        case .open:
            return ("ellipsis-h", "color-gray-50")
        case .closed:
            return ("times", "color-invalid")
        case .voided:
            return ("ban", "color-invalid")
        case .processing:
            return ("refresh", "color-gray-50 fa-spin")
        }
    }
}

func screenReader(_ text: String) -> Node {
    return .span(classes: "sr-only", [.text(text)])
}

struct Column {
    enum Alignment: String {
        case left
        case right
        case center
    }
    var title: String
    var alignment: Alignment
    init(title: String, alignment: Alignment = .left) {
        self.title = title
        self.alignment = alignment
    }
}

struct Cell {
    var children: [Node]
    var classes: Class = ""
    init(_ children: [Node], classes: Class = "") {
        self.children = children
        self.classes = classes
    }
    
    init(_ text: String, classes: Class = "") {
        self.children = [.text(text)]
        self.classes = classes
    }
    
}
func table(columns: [Column], cells: [[Cell]]) -> Node {
    return .div(classes: "table-responsive", [
        .table(classes: "width-full ms-1", [
            .thead(classes: "bold color-gray-15", [
                .tr(columns.map { column in
                    let align = Class(stringLiteral: "text-" + column.alignment.rawValue)
                    return .th(classes: "pv ph-" + align, attributes: ["scope": "col"], [.text(column.title)])
                })
            ]),
            .tbody(classes: "color-gray-30", cells.map { row in
                return .tr(classes: "border-top border-1 border-color-gray-90", row.map { cell in
                    .td(classes: "pv ph- no-wrap" + cell.classes, cell.children)
                })
            })
        ])
    ])
}

func invoicesView(user: Row<UserData>, invoices: [(Invoice, pdfURL: URL)]) -> [Node] {
    guard !invoices.isEmpty else { return  [
        .div(classes: "text-center", [
        	.p(classes: "color-gray-30 ms1 mb", [.text("No invoices yet.")])
    	])
    ] }
    
    let columns = [Column(title: "Status"),
                   Column(title: "Number"),
                   Column(title: "Date"),
                   Column(title: "Amount", alignment: .right),
                   Column(title: "PDF", alignment: .center),
                  ]
    let cells: [[Cell]] = invoices.map { x in
        let (invoice, pdfURL) = x
        return [
            Cell(invoice.state.rawValue),
            Cell("# \(invoice.invoice_number)"),
            Cell(DateFormatter.fullPretty.string(from: invoice.created_at)),
            Cell(dollarAmount(cents: invoice.total_in_cents), classes: "type-mono text-right"),
            Cell([.link(to: pdfURL, classes: "", [.text("\(invoice.invoice_number).pdf")])], classes: "text-center"),
        ]
    }
    return [
        heading("Invoice History"),
        table(columns: columns, cells: cells)
    ]
}

fileprivate func heading(_ string: String) -> Node {
    return .h2(classes: "color-blue bold ms2 mb", [.text(string)])
}

extension Subscription.State {
    var pretty: String {
        switch self {
        case .active:
            return "Active"
        case .canceled:
            return "Canceled"
        case .future:
            return "Future"
        case .expired:
            return "Expired"
        }
    }
}


extension Subscription.Upgrade {
    func pretty() -> [Node] {
        let vat = vat_in_cents == 0 ? "" : " (including \(dollarAmount(cents: vat_in_cents)) VAT)"
        let teamMemberText: String
        if team_members == 1 {
            teamMemberText = ". This includes your team member"
        } else if team_members > 1 {
            teamMemberText = ". This includes your \(team_members) team members"
        } else {
            teamMemberText = ""
        }
        return [
                .p([.text("Upgrade to the \(plan.name) plan.")]),
                .p(classes: "lh-110", [.text(
                    "Your new plan will cost \(dollarAmount(cents: total_in_cents)) \(plan.prettyInterval)" +
                        vat +
                        teamMemberText +
                    ". You'll be charged immediately, and credited for the remainder of the current billing period."
                    )]),
                button(to: .subscription(.upgrade), text: "Upgrade Subscription", classes: "color-invalid")
            ]
    }
}

struct PaymentViewData: Codable {
    var first_name: String?
    var last_name: String?
    var company: String?
    var address1: String?
    var address2: String?
    var city: String?
    var state: String?
    var zip: String?
    var country: String?
    var phone: String?
    var year: Int
    var month: Int
    var action: String
    var public_key: String
    var buttonText: String
    var vat_number: String?
    struct Coupon: Codable { }
    var payment_errors: [String] // TODO verify type
    var method: HTTPMethod = .post
    var coupon: Coupon
    var csrf: CSRFToken
    
    init(_ billingInfo: BillingInfo, action: String, csrf: CSRFToken, publicKey: String, buttonText: String, paymentErrors: [String]) {
        first_name = billingInfo.first_name
        last_name = billingInfo.last_name
        company = billingInfo.company
        address1 = billingInfo.address1
        address2 = billingInfo.address2
        city = billingInfo.city
        state = billingInfo.state
        zip = billingInfo.zip
        country = billingInfo.country
        phone = billingInfo.phone
        year = billingInfo.year
        month = billingInfo.month
        vat_number = billingInfo.vat_number
        self.action = action
        self.public_key = publicKey
        self.buttonText = buttonText
        self.payment_errors = paymentErrors
        self.method = .post
        self.coupon = Coupon()
        self.csrf = csrf
    }
}

extension ReactComponent where A == PaymentViewData {
    static let creditCard: ReactComponent<A> = ReactComponent(name: "CreditCard")
}

func updatePaymentView(data: PaymentViewData) -> Node {
    return LayoutConfig(contents: [
        accountHeader,
        accountContainer(content: .div([
            heading("Update Payment Method"),
            .div(classes: "container", [
               ReactComponent.creditCard.build(data)
            ])
        ]), forRoute: .account(.updatePayment))
    ], includeRecurlyJS: true).layout
}

extension BillingInfo {
    var cardMask: String {
        return "\(first_six.first!)*** **** **** \(last_four)"
    }
    var show: [Node] {
        func item(key: String, value v: String, classes: Class? = nil) -> Node {
            return .li(classes: "flex", [
                label(text: key),
                value(text: v)
            ])
        }
        return [
            heading("Billing Info"),
            .div([
                .ul(classes: "stack- mb", [
                    item(key: "Type", value: card_type),
                    item(key: "Number", value: cardMask, classes: .some("type-mono")) as Node,
                    item(key: "Expiry", value: "\(month)/\(year)") as Node,
                    vat_number?.nonEmpty.map { num in
                        item(key: "VAT Number", value: num)
                    } ?? .none
                ])
            ]),
            .link(to: .account(.updatePayment), classes: "color-blue no-decoration border-bottom border-1 hover-color-black bold", [.text("Update Billing Info")])
        ]
    }
}

fileprivate func button(to route: Route, text: String, classes: Class = "") -> Node {
    return .withCSRF { csrf in
    	return .button(to: route, classes: "bold reset-button border-bottom border-1 hover-color-black" + classes, [.text(text)])
    }
}

fileprivate func label(text: String, classes: Class = "") -> Node {
    return .strong(classes: "flex-none width-4 bold color-gray-15" + classes, [.text(text)])
}

fileprivate func value(text: String, classes: Class = "") -> Node {
    return .span(classes: "flex-auto color-gray-30" + classes, [.text(text)])
}

func billingLayout(_ content: [Node]) -> Node {
    return LayoutConfig(contents: [
        accountHeader,
        accountContainer(content: .div(classes: "stack++", content), forRoute: .account(.billing))
    ]).layout
}

func teamMemberBillingContent() -> [Node] {
    return [
        .div([
            heading("Subscription"),
            .p(classes: "lh-110", [.text("You have a team member account, which doesn't have its own billing info.")])
        ])
    ]
}

func gifteeBillingContent() -> [Node] {
    return [
        .div([
            heading("Subscription"),
            .p(classes: "lh-110", [.text("You currently have an active gift subscription, which doesn't have its own billing info.")])
        ])
    ]
}

func unsubscribedBillingContent() -> [Node] {
    return [
        .div([
            heading("Subscription"),
            .p(classes: "mb", [.text("You don't have an active subscription.")]),
            .link(to: .signup(.subscribe), classes: "c-button", [.text("Become a Subscriber")])
        ])
    ]
}

func billingView(subscription: (Subscription, Plan.AddOn)?, invoices: [(Invoice, pdfURL: URL)], billingInfo: BillingInfo, redemptions: [(Redemption, Coupon)]) -> Node {
    return .withSession { session in
        guard let session = session else { return billingLayout(unsubscribedBillingContent()) }
        let user = session.user
        let subscriptionInfo: [Node]
        if let (sub, addOn) = subscription {
            let (total, vat) = sub.totalAtRenewal(addOn: addOn, vatExempt: billingInfo.vatExempt)
            subscriptionInfo = [
                .div([
                    heading("Subscription"),
                    .div([
                        .ul(classes: "stack- mb", [
                            .li(classes: "flex", [
                                label(text: "Plan"),
                                value(text: sub.plan.name)
                            ]),
                            .li(classes: "flex", [
                                label(text: "State"),
                                value(text: sub.state.pretty)
                            ]),
                            sub.trial_ends_at.map { trialEndDate in
                                .li(classes: "flex", [
                                    label(text: "Trial Ends At"),
                                    value(text: DateFormatter.fullPretty.string(from: trialEndDate))
                                ])
                            } ?? Node.none,
                            sub.state == .active ? Node.li(classes: "flex", [
                                label(text: "Next Billing"),
                                .div(classes: "flex-auto color-gray-30 stack-", [
                                    .p([
                                        .text(dollarAmount(cents: total)),
                                        vat == 0 ? .none : .text(" (including \(dollarAmount(cents: vat)) VAT)"),
                                        .text(" on "),
                                        .text(sub.current_period_ends_at.map { DateFormatter.fullPretty.string(from: $0) } ?? "n/a"),
                                    ]),
                                    redemptions.isEmpty ? .none : .p(classes: " input-note mt-", [
                                        .span(classes: "bold", [.text("Note:")])
                                    ] + redemptions.map { x in
                                        let (redemption, coupon) = x
                                        let start = DateFormatter.fullPretty.string(from: redemption.created_at)
                                        return .text("Due to a technical limation, the displayed price does not take your active coupon (\(coupon.billingDescription), started at \(start)) into account.")
                                    }),
                                    button(to: .subscription(.cancel), text: "Cancel Subscription", classes: "color-invalid")
                                ])
                            ]) : .none,
                            sub.upgrade(vatExempt: billingInfo.vatExempt).map { upgrade in
                                .li(classes: "flex", [
                                    label(text: "Upgrade"),
                                    .div(classes: "flex-auto color-gray-30 stack--", upgrade.pretty())
                                ])
                            } ?? .none,
                            sub.state == .canceled ? Node.li(classes: "flex", [
                                label(text: "Expires on"),
                                .div(classes: "flex-auto color-gray-30 stack-", [
                                    .text(sub.expires_at.map { DateFormatter.fullPretty.string(from: $0) } ?? "<unknown date>"),
                                    button(to: .subscription(.reactivate), text: "Reactivate Subscription", classes: "color-invalid")
                                ])
                            ]) : .none
                        ])
                    ])
                ]),
                .div(billingInfo.show)
            ]
        } else if session.gifterPremiumAccess {
            subscriptionInfo = gifteeBillingContent()
        } else if session.teamMemberPremiumAccess {
            subscriptionInfo = teamMemberBillingContent()
        } else {
            subscriptionInfo = session.activeSubscription ? [] : unsubscribedBillingContent()
        }
        return billingLayout(subscriptionInfo + [.div(invoicesView(user: user, invoices: invoices))])
    }
}

func accountForm() -> Form<ProfileFormData, STRequestEnvironment> {
    // todo button color required fields.
    let form = profile(submitTitle: "Update Profile", action: .account(.profile))
    return form.wrap { node in
        LayoutConfig(contents: [
            accountHeader,
            accountContainer(content: node, forRoute: .account(.profile))
        ]).layout
    }
}


func teamMembersView(teamMembers: [Row<UserData>], signupLink: URL) -> Node {
    func row(avatarURL: String, name: String, email: String, githubLogin: String, deleteRoute: Route?) -> Node {
        return .div(classes: "flex items-center pv- border-top border-1 border-color-gray-90", [
            .div(classes: "block radius-full ms-2 width-2 mr", [
                .img(classes: "block radius-full ms-2 width-2 mr", src: avatarURL)
            ]),
            .div(classes: "cols flex-grow" + (deleteRoute == nil ? "bold" : ""), [
                .div(classes: "col width-1/3", [.text(name)]),
                .div(classes: "col width-1/3", [.text(email)]),
                .div(classes: "col width-1/3", [.text(githubLogin)]),
            ]),
            .div(classes: "block width-2", [
                deleteRoute.map { .button(to: $0, confirm: "Are you sure to delete this team member?", classes: "button-input ms-1", [.raw("&times;")]) } ?? ""
            ]),
        ])
    }
    let currentTeamMembers: Node
    if teamMembers.isEmpty {
        currentTeamMembers = .p(classes: "c-text", ["No team members added yet."])
    } else {
        let headerRow = row(avatarURL: "", name: "Name", email: "Email", githubLogin: "Github Handle", deleteRoute: nil)
        currentTeamMembers = .div([headerRow] + teamMembers.compactMap { tm in
            guard let githubLogin = tm.data.githubLogin else { return nil }
            return row(avatarURL: tm.data.avatarURL, name: tm.data.name, email: tm.data.email, githubLogin: githubLogin, deleteRoute: .account(.deleteTeamMember(tm.id)))
        })
    }
    
    let content: [Node] = [
        .div(classes: "stack++", [
            .div([
                heading("Add Team Members"),
                .div(classes: "color-gray-25 lh-110", [
                    .p(["To add team members, please send them the following link for signup:"]),
                    .div(classes: "type-mono ms-1 mv", [.text(signupLink.absoluteString)]),
                    .p(classes: "color-gray-50 ms-1", ["Team members cost $10/month or $100/year (excl. VAT), depending on your subscription."]),
                    .button(to: .account(.invalidateTeamToken), confirm: "WARNING: This will invalidate the current signup link. Do you want to proceed?", classes: "button mt+", ["Generate New Signup Link"]),
                ])
            ]),
            .div([
                heading("Current Team Members"),
                currentTeamMembers
            ])
        ])
    ]

    return LayoutConfig(contents: [
        accountHeader,
        accountContainer(content: .div(classes: "stack++", [
            .div(content)
        ]), forRoute: .account(.teamMembers))
    ]).layout
}
