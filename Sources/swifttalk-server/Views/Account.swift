//
//  Account.swift
//  Bits
//
//  Created by Chris Eidhof on 06.11.18.
//

import Foundation

func renderAccount(context: Context) -> Node {
    return LayoutConfig(context: context, contents: [
        pageHeader(.link(header: "Account", backlink: .home, label: "")),
        .div(classes: "container pb0", [
            .div([
                .h2([.span(attributes: ["class": "bold"], [.text("\(context.session!.user)")])], attributes: ["class": "inline-block lh-100 mb+"])
                ]),
            ])
    ]).layout
}
