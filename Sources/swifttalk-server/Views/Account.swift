//
//  Account.swift
//  Bits
//
//  Created by Chris Eidhof on 06.11.18.
//

import Foundation

func accountContainer(_ node: Node, forRoute: Route) -> Node {
    let items: [(Route, title: String)] = [
        (Route.accountProfile, title: "Profile"),
        (Route.accountBilling, title: "Billing"),
        (Route.accountTeamMembers, title: "Team Members"),
        (Route.logout, title: "Logout"),
    ]
    return .div(classes: "container pb0", [
        .div(classes: "cols m-|stack++", [
            .div(classes: "col width-full m+|width-1/4", [
                Node.div(classes: "submenu", items.map { item in
                    Node.link(to: item.0, [.text(item.title)], classes: "submenu__item" + (item.0 == forRoute ? "is-active" : ""), attributes: [:])
                })
            ]),
            .div(classes: "col width-full m+|width-3/4", [node])
        ])
    ])
}

// Icon from font-awesome
func faIcon(name: String, classes: Class = "") -> Node {
    let iconName = Class(stringLiteral: "fa-" + name)
    return Node.i(classes: "fa" + iconName + classes)
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

func billing(context: Context, user: Row<UserData>, invoices: [(Invoice, pdfURL: URL)]) -> Node {
    let pitch = user.data.subscriber ? .none : Node.div([
        Node.div(classes: "text-center", [
            Node.p(classes: "color-gray-30 ms1 mb", [.text("You don't have an active subscription.")]),
            Node.link(to: .subscribe, [.text("Become a Subscriber")], classes: "c-button")
        ])
    ])
    let invoices: [Node] = invoices.isEmpty ? [Node.div(classes: "text-center", [
        Node.p(classes: "color-gray-30 ms1 mb", [.text("No invoices yet.")])
    ])] : [
        Node.h2(classes: "color-blue bold ms2 mb-", [.text("Invoice History")]),
        Node.div(classes: "table-responsive",
                 [Node.table(classes: "width-full ms-1", [
                    Node.thead(classes: "bold color-gray-15",
                        [Node.tr([
                            Node.th(classes: "pv ph- text-left", attributes: ["scope": "col"], [.text("Status")]),
                            Node.th(classes: "pv ph- text-left", attributes: ["scope": "col"], [.text("Number")]),
                            Node.th(classes: "pv ph- text-left", attributes: ["scope": "col"], [.text("Date")]),
                            Node.th(classes: "pv ph- text-left text-right", attributes: ["scope": "col"], [.text("Amount")]),
                            Node.th(classes: "pv ph- text-left text-center", attributes: ["scope": "col"], [.text("PDF")])
                    	])]
                    ),
                    Node.tbody(classes: "color-gray-30", invoices.map { x in
                        let (invoice, pdfURL) = x
                        print(pdfURL)
//                        let (icon, cl) = invoice.state.icon
                        return Node.tr(classes: "border-top border-1 border-color-gray-90", [
                            Node.td(classes: "pv ph-", [
//                                faIcon(name: icon, classes: cl),
//                                screenReader(invoice.state.rawValue)
                                .text("\(invoice.state.rawValue)")
                                ]), // todo icon
                            Node.td(classes: "pv ph- no-wrap", [.text("# \(invoice.invoice_number)")]),
                            Node.td(classes: "pv ph- no-wrap", [.text("\(DateFormatter.fullPretty.string(from: invoice.created_at))")]),
                            Node.td(classes: "pv ph- no-wrap type-mono text-right", [.text(dollarAmount(cents: invoice.total_in_cents))]),
                            Node.td(classes: "pv ph- no-wrap text-center", [
                                Node.externalLink(to: pdfURL, classes: "", children: [.text("\(invoice.invoice_number).pdf")])
                            ]) // todo icone
                        ])
                    })
                ])
            ])
    ]
    
     // todo team members?
    return LayoutConfig(context: context, contents: [        
        pageHeader(.link(header: "Account", backlink: .home, label: "")),
        accountContainer(Node.div(classes: "stack++", [
            pitch,
            Node.div(invoices)
        ]), forRoute: .accountBilling)
    ]).layout
}

func accountForm(context: Context) -> Form<ProfileFormData> {
    // todo button color required fields.
    let form = profile(submitTitle: "Update Profile", action: .accountProfile)
    return form.wrap { node in
        LayoutConfig(context: context, contents: [
            pageHeader(.link(header: "Account", backlink: .home, label: "")),
            accountContainer(node, forRoute: .accountProfile)
        ]).layout
    }
}


struct TeamMemberFormData {
    var githubUsername: String
}

func teamMembers(context: Context, user: Row<UserData>) -> Node {
    let pitch = user.data.subscriber ? .none : Node.div([
        Node.div(classes: "text-center", [
            Node.p(classes: "color-gray-30 ms1 mb", [.text("You don't have an active subscription.")]),
            Node.link(to: .subscribe, [.text("Become a Subscriber")], classes: "c-button")
            ])
        ])

    let addForm = Form<TeamMemberFormData>(parse: { dict in
        guard let username = dict["github_username"] else { return nil }
        return TeamMemberFormData(githubUsername: username)
    }, render: { data, errors in
        let form = FormView(fields: [
            FormView.Field(id: "github_username", title: "Github Username", value: data.githubUsername, note: "Your new team member won’t be notified, as we don’t have their email address yet."),
        ], submitTitle: "Add for TODO Monthly", submitNote: "All prices excluding VAT.", action: .accountTeamMembers, errors: errors)
        return .div(form.renderStacked)
    })

    let content: [Node] = [
        Node.h2(classes: "color-blue bold ms2 mb-", [.text("Team Members")]),
        addForm.render(TeamMemberFormData(githubUsername: ""), [])
    ]

    return LayoutConfig(context: context, contents: [
        pageHeader(HeaderContent.other(header: "Account", blurb: nil, extraClasses: "ms4 pb")),
        accountContainer(Node.div(classes: "stack++", [
            pitch,
            Node.div(content)
            ]), forRoute: .accountTeamMembers)
        ]).layout
}
