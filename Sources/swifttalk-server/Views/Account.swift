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

func billing(context: Context, user: Row<UserData>, invoices: [Invoice]) -> Node {
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
                            Node.th(classes: "pv ph- text-left", attributes: ["scope": "col"], [.text("Amount")]),
                            Node.th(classes: "pv ph- text-left", attributes: ["scope": "col"], [.text("PDF")])
                    	])]
                    ),
                    Node.tbody(classes: "color-gray-30", invoices.map { invoice in
                        let amount = String(format: "%.2f", Double(invoice.total_in_cents) / 100)
                        return Node.tr(classes: "border-top border-1 border-color-gray-90", [
                            Node.td(classes: "pv ph- no-wrap", attributes: ["scope": "col"], [.text(invoice.state)]), // todo icon
                            Node.td(classes: "pv ph- no-wrap", attributes: ["scope": "col"], [.text("\(invoice.invoice_number)")]),
                            Node.td(classes: "pv ph- no-wrap", attributes: ["scope": "col"], [.text("\(DateFormatter.fullPretty.string(from: invoice.created_at))")]),
                            Node.td(classes: "pv ph- no-wrap", attributes: ["scope": "col"], [.text("$ \(amount)")]),
                            Node.td(classes: "pv ph- no-wrap", attributes: ["scope": "col"], [.text("PDF")]) // todo
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
