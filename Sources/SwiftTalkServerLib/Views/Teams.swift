//
//  Teams.swift
//  Bits
//
//  Created by Florian Kugler on 10-01-2019.
//

import Foundation

fileprivate let signupHeader = pageHeader(.other(header: "Team Member Signup", blurb: nil, extraClasses: "ms4"), extraClasses: "text-center")

func teamMemberSignupAlreadySubscribed() throws -> Node {
    let contents: [Node] = [
        signupHeader,
        .section(classes: "container", [
            .div(classes: "c-text text-center cols max-width-8 center", [
                .p([.text("You already have an active subscription at this moment.")]),
                .p([.text("To change your subscription to the team you've been invited to, please cancel your own subscription and signup as a team member once your old subscription has expired.")]),
                .p([
                    .text("To expedite this process, please get in touch at"),
                    .link(to: URL(string: "mailto:\(email)")!, [.text(email)]),
                    .text(".")
                ]),
            ])
        ])
    ]
    return LayoutConfig(pageTitle: "Redeem Your Gift", contents: contents).layout
}

func teamMemberSubscribe(signupToken: UUID) throws -> Node {
    let contents: [Node] = [
        signupHeader,
        .div(classes: "container pt0", [
            .div(classes: "bgcolor-white pa- radius-8 max-width-7 box-sizing-content center stack-", [
                Node.div(classes: "text-center mt+", [
                    .div(classes: "c-text mt mb-", [
                        .p([.text("Welcome to Swift Talk!")]),
                        .p([.text("You're one step away from signing up as a team member:")]),
                    ]),
                ]),
                .div([
                    Node.link(to: Route.login(continue: Route.subscription(.teamMember(token: signupToken))), classes: "mt+ c-button c-button--big c-button--blue c-button--wide", ["Start By Logging In With GitHub"])
                ])
            ])
        ])
    ]
    return LayoutConfig(pageTitle: "Team Member Signup", contents: contents).layout
}

