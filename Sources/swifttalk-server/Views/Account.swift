//
//  Account.swift
//  Bits
//
//  Created by Chris Eidhof on 06.11.18.
//

import Foundation

func accountForm(context: Context) -> Form<ProfileFormData> {
    let form = profile(context, submitTitle: "Update Profile", action: .accountBilling)
    return form.wrap { node in
        LayoutConfig(context: context, contents: [
            pageHeader(.link(header: "Account", backlink: .home, label: "")),
            .div(classes: "container pb0", [node]) // todo button color required fields.
        ]).layout
    }
}
