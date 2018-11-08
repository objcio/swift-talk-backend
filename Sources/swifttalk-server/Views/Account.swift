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

func billing(context: Context, user: Row<UserData>) -> Node {
    let pitch = user.data.subscriber ? .none : Node.div([
        Node.div(classes: "text-center", [
            Node.p(classes: "color-gray-30 ms1 mb", [.text("You don't have an active subscription.")]),
            Node.link(to: .subscribe, [.text("Become a Subscriber")], classes: "c-button")
        ])
    ])
    return LayoutConfig(context: context, contents: [
        pageHeader(.link(header: "Account", backlink: .home, label: "")),
        accountContainer(Node.div(classes: "stack++", [
            pitch
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
