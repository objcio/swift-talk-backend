//
//  Login.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 18-01-2019.
//

import Foundation

struct LoginFormData {
    var username: String
    var password: String
}

fileprivate func continueLink(to route: Route, title: String, extraClasses: Class? = nil) -> Node {
    let linkClasses: Class = "c-button c-button--big c-button--blue c-button--wide"
    return Node.link(to: route, classes: linkClasses + (extraClasses ?? ""), [.text(title)])
}

func usernamePasswordForm(origin: Route?, couponCode: String?, team: Bool) -> Form<LoginFormData> {
    return Form(parse: { dict in
        guard let u = dict["username"], let p = dict["password"] else { return nil }
        return LoginFormData(username: u, password: p)
    }, render: { data, errors in
        let form = FormView(fields: [
            .text(id: "username", title: "Username", value: data.username, note: nil),
            .fieldSet([
                .input(id: "password", value: data.password, type: "password", placeHolder: nil, otherAttributes: [:])
                ], required: true, title: "Password", note: nil)
            ], submitTitle: "Login", action: .login(continue: origin, couponCode: couponCode, team: team), errors: errors)
        return .div(form.renderStacked())
    })
}

func loginForm(origin: Route, couponCode: String?, team: Bool) -> Form<LoginFormData> {
    let form = usernamePasswordForm(origin: origin, couponCode: couponCode, team: team)
    return form.wrap { node in
        LayoutConfig(contents: [
            Node.header([
                Node.div(classes: "container-h pb+ pt- max-width-6 text-center", [
                    Node.h1(classes: "ms4 color-blue bold", ["Login"])
                ]),
            ]),
            Node.div(classes: "container max-width-6 text-center", [
                node,
                .div(classes: "input-label mv+", ["or"]),
                continueLink(to: .loginWithGithub(continue: origin), title: "Login with Github"),
                .div(classes: "mt+", [
                    .link(to: .forgotPassword, classes: "ms-1 color-gray-60 no-decoration", ["Forgot your password?"])
                ])
            ])
        ]).layoutForCheckout
    }
}

