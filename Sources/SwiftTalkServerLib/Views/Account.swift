//
//  Account.swift
//  Bits
//
//  Created by Chris Eidhof on 06.11.18.
//

import Foundation
import Base
import HTML1
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
        return .div(class: "container pb0", [
            .div(class: "cols m-|stack++", [
                .div(class: "col width-full m+|width-1/4", [
                    .div(class: "submenu", items.map { item in
                        .link(to: item.0, class: "submenu__item" + (item.0 == forRoute ? "is-active" : ""), attributes: [:], [.text(item.title)])
                    })
                ]),
                .div(class: "col width-full m+|width-3/4", [content])
            ])
        ])
    }
}

func screenReader(_ text: String) -> Node {
    return .span(class: "sr-only", [.text(text)])
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
    var `class`: Class = ""
    init(_ children: [Node], class: Class = "") {
        self.children = children
        self.class = `class`
    }
    
    init(_ text: String, class: Class = "") {
        self.children = [.text(text)]
        self.class = `class`
    }
    
}
func table(columns: [Column], cells: [[Cell]]) -> Node {
    return .div(class: "table-responsive", [
        .table(class: "width-full ms-1", [
            .thead(class: "bold color-gray-15", [
                .tr(columns.map { column in
                    let align = Class(stringLiteral: "text-" + column.alignment.rawValue)
                    return .th(class: "pv ph-" + align, attributes: ["scope": "col"], [.text(column.title)])
                })
            ]),
            .tbody(class: "color-gray-30", cells.map { row in
                return .tr(class: "border-top border-1 border-color-gray-90", row.map { cell in
                    .td(class: "pv ph- no-wrap" + cell.class, cell.children)
                })
            })
        ])
    ])
}

func invoicesView(user: Row<UserData>, invoices: [(Invoice, pdfURL: URL)]) -> [Node] {
    guard !invoices.isEmpty else { return  [
        .div(class: "text-center", [
        	.p(class: "color-gray-30 ms1 mb", ["No invoices yet."])
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
            Cell(dollarAmount(cents: invoice.total_in_cents), class: "type-mono text-right"),
            Cell([.link(to: pdfURL, class: "", ["\(invoice.invoice_number).pdf"])], class: "text-center"),
        ]
    }
    return [
        heading("Invoice History"),
        table(columns: columns, cells: cells)
    ]
}

fileprivate func heading(_ string: String) -> Node {
    return .h2(class: "color-blue bold ms2 mb", [.text(string)])
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
                .p(["Upgrade to the \(plan.name) plan."]),
                .p(class: "lh-110", [
                    .text(
                        "Your new plan will cost \(dollarAmount(cents: total_in_cents)) \(plan.prettyInterval)" +
                        vat +
                        teamMemberText +
                        ". You'll be charged immediately, and credited for the remainder of the current billing period."
                    ),
                    .button(to: .subscription(.upgrade), class: "button button--tight", ["Confirm Upgrade"])
                ])
            ]
    }
}

func updatePaymentView(data: SubscriptionFormData, initial: BillingInfo) -> Node {
    return LayoutConfig(contents: [
        accountHeader,
        accountContainer(content: .div([
            heading("Update Payment Method"),
            subscriptionForm(data, initial: initial, action: .account(.updatePayment))
        ]), forRoute: .account(.billing))
    ], includeRecurlyJS: true).layout
}

func noBillingInfoView() -> Node {
    return LayoutConfig(contents: [
        accountHeader,
        accountContainer(content: .div([
            heading("Update Payment Method"),
            .p(["No billing info present."])
        ]), forRoute: .account(.billing))
    ]).layout
}

extension BillingInfo {
    var cardMask: String {
        return "\(first_six.first!)*** **** **** \(last_four)"
    }
    var show: [Node] {
        func item(key: String, value v: String, class: Class? = nil) -> Node {
            return .li(class: "flex", [
                label(text: key),
                value(text: v)
            ])
        }
        return [
            heading("Billing Info"),
            .div([
                .ul(class: "stack- mb", [
                    item(key: "Type", value: card_type),
                    item(key: "Number", value: cardMask, class: .some("type-mono")) as Node,
                    item(key: "Expiry", value: "\(month)/\(year)") as Node,
                    vat_number?.nonEmpty.map { num in
                        item(key: "VAT Number", value: num)
                    } ?? .none
                ])
            ]),
            .link(to: .account(.updatePayment), class: "color-blue no-decoration border-bottom border-1 hover-color-black bold", ["Update Billing Info"])
        ]
    }
}

fileprivate func button(to route: Route, text: String, class: Class = "") -> Node {
    return .withCSRF { csrf in
    	return .button(to: route, class: "bold reset-button border-bottom border-1 hover-color-black" + `class`, [.text(text)])
    }
}

fileprivate func label(text: String, class: Class = "") -> Node {
    return .strong(class: "flex-none width-4 bold color-gray-15" + `class`, [.text(text)])
}

fileprivate func value(text: String, class: Class = "") -> Node {
    return .span(class: "flex-auto color-gray-30" + `class`, [.text(text)])
}

func billingLayout(_ content: [Node]) -> Node {
    return LayoutConfig(contents: [
        accountHeader,
        accountContainer(content: .div(class: "stack++", content), forRoute: .account(.billing))
    ]).layout
}

func teamMemberBillingContent() -> [Node] {
    return [
        .div([
            heading("Subscription"),
            .p(class: "lh-110", ["You have a team member account, which doesn't have its own billing info."])
        ])
    ]
}

func gifteeBillingContent() -> [Node] {
    return [
        .div([
            heading("Subscription"),
            .p(class: "lh-110", ["You currently have an active gift subscription, which doesn't have its own billing info."])
        ])
    ]
}

func unsubscribedBillingContent() -> [Node] {
    return [
        .div([
            heading("Subscription"),
            .p(class: "mb", ["You don't have an active subscription."]),
            .link(to: .signup(.subscribe(planName: nil)), class: "c-button", ["Become a Subscriber"])
        ])
    ]
}

func billingView(subscription: (Subscription, Plan.AddOn)?, invoices: [(Invoice, pdfURL: URL)], billingInfo: BillingInfo?, redemptions: [(Redemption, Coupon)]) -> Node {
    return .withSession { session in
        guard let session = session else { return billingLayout(unsubscribedBillingContent()) }
        let user = session.user
        let subscriptionInfo: [Node]
        if let (sub, addOn) = subscription {
            let nextBilling: Node
            if sub.state == .active, let b = billingInfo {
                let (total, vat) = sub.totalAtRenewal(addOn: addOn, vatExempt: b.vatExempt)
                nextBilling = .li(class: "flex", [
                    label(text: "Next Billing"),
                    .div(class: "flex-auto color-gray-30 stack-", [
                        .p([
                            .text(dollarAmount(cents: total)),
                            vat == 0 ? .none : " (including \(dollarAmount(cents: vat)) VAT)",
                            " on ",
                            .text(sub.current_period_ends_at.map { DateFormatter.fullPretty.string(from: $0) } ?? "n/a"),
                        ]),
                        redemptions.isEmpty ? .none : .p(class: " input-note mt-", [
                            .span(class: "bold", ["Note:"])
                        ] + redemptions.map { x in
                            let (redemption, coupon) = x
                            let start = DateFormatter.fullPretty.string(from: redemption.created_at)
                            return "Due to a technical limation, the displayed price does not take your active coupon (\(coupon.billingDescription), started at \(start)) into account."
                        }),
                        button(to: .subscription(.cancel), text: "Cancel Subscription", class: "color-invalid")
                    ])
                ])            } else {
                nextBilling = .none
            }
            let upgrade: Node
            if let vatExempt = billingInfo?.vatExempt, let u = sub.upgrade(vatExempt: vatExempt) {
                upgrade = .li(class: "flex", [
                    label(text: "Upgrade"),
                    .div(class: "flex-auto color-gray-30 stack--", u.pretty())
                ])
            } else {
                upgrade = .none
            }
            subscriptionInfo = [
                .div([
                    heading("Subscription"),
                    .div([
                        .ul(class: "stack- mb", [
                            .li(class: "flex", [
                                label(text: "Plan"),
                                value(text: sub.plan.name)
                            ]),
                            .li(class: "flex", [
                                label(text: "State"),
                                value(text: sub.state.pretty)
                            ]),
                            sub.trial_ends_at.map { trialEndDate in
                                .li(class: "flex", [
                                    label(text: "Trial Ends At"),
                                    value(text: DateFormatter.fullPretty.string(from: trialEndDate))
                                ])
                            } ?? Node.none,
                            nextBilling,
                            upgrade,
                            sub.state == .canceled && billingInfo != nil ? Node.li(class: "flex", [
                                label(text: "Expires on"),
                                .div(class: "flex-auto color-gray-30 stack-", [
                                    .text(sub.expires_at.map { DateFormatter.fullPretty.string(from: $0) } ?? "<unknown date>"),
                                    button(to: .subscription(.reactivate), text: "Reactivate Subscription", class: "color-invalid")
                                ])
                            ]) : .none
                        ])
                    ])
                ]),
                .div(billingInfo?.show ?? [])
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


func teamMembersView(teamMembers: [Row<UserData>], price: String?, signupLink: URL) -> Node {
    func row(avatarURL: String, name: String, email: String, githubLogin: String, deleteRoute: Route?) -> Node {
        return .div(class: "flex items-center pv- border-top border-1 border-color-gray-90", [
            .div(class: "block radius-full ms-2 width-2 mr", [
                .img(class: "block radius-full ms-2 width-2 mr", src: avatarURL)
            ]),
            .div(class: "cols flex-grow" + (deleteRoute == nil ? "bold" : ""), [
                .div(class: "col width-1/3", [.text(name)]),
                .div(class: "col width-1/3", [.text(email)]),
                .div(class: "col width-1/3", [.text(githubLogin)]),
            ]),
            .div(class: "block width-2", [
                deleteRoute.map { .button(to: $0, confirm: "Are you sure to delete this team member?", class: "button-input ms-1", [.raw("&times;")]) } ?? ""
            ]),
        ])
    }
    let currentTeamMembers: Node
    if teamMembers.isEmpty {
        currentTeamMembers = .p(class: "c-text", ["No team members added yet."])
    } else {
        let headerRow = row(avatarURL: "", name: "Name", email: "Email", githubLogin: "Github Handle", deleteRoute: nil)
        currentTeamMembers = .div([headerRow] + teamMembers.compactMap { tm in
            guard let githubLogin = tm.data.githubLogin else { return nil }
            return row(avatarURL: tm.data.avatarURL, name: tm.data.name, email: tm.data.email, githubLogin: githubLogin, deleteRoute: .account(.deleteTeamMember(tm.id)))
        })
    }
    
    let content: [Node] = [
        .div(class: "stack++", [
            .div([
                heading("Add Team Members"),
                .div(class: "color-gray-25 lh-110", [
                    .p(["To add team members, please send them the following link for signup:"]),
                    .div(class: "type-mono ms-1 mv", [.text(signupLink.absoluteString)]),
                    price.map { .p(class: "color-gray-50 ms-1", [.text("Team members cost \($0) (excl. VAT).")]) } ?? .none,
                    .button(to: .account(.invalidateTeamToken), confirm: "WARNING: This will invalidate the current signup link. Do you want to proceed?", class: "button mt+", ["Generate New Signup Link"]),
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
        accountContainer(content: .div(class: "stack++", [
            .div(content)
        ]), forRoute: .account(.teamMembers))
    ]).layout
}
