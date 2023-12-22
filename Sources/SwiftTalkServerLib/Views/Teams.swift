//
//  Teams.swift
//  Bits
//
//  Created by Florian Kugler on 10-01-2019.
//

import Foundation
import HTML1


fileprivate let signupHeader = pageHeader(.other(header: "Team Member Signup", blurb: nil, extraClasses: "ms4"), extraClasses: "text-center")

fileprivate func template(content: [Node], buttons: [Node]) -> Node {
    return LayoutConfig(pageTitle: "Join Team", contents: [
        signupHeader,
        .section(class: "container", [
            .div(class: "text-center center max-width-8", [
                .div(class: "c-text", content),
                .div(class: "mt++", buttons)
            ])
        ])
    ]).layout
}

fileprivate func button(route: Route, title: String, highlighted: Bool = false) -> Node {
    return .link(to: route, class: "mb c-button c-button--big ph+++" + (highlighted ? "c-button--orange" : "c-button--blue"), [.text(title)])
}

func teamMemberSubscribeForSelfSubscribed(signupToken: UUID) -> Node {
    return template(content: [
        .p(class: "center bold", ["You already have an active subscription."]),
        .p(class: "center", ["You can register as a team member using the orange button below. Your current individual subscription will end immediately and you will receive a refund for the remainder of the current billing cycle. If you wish to keep your existing subscription, press the blue button."]),
    ], buttons: [
        button(route: .subscription(.registerAsTeamMember(token: signupToken, terminate: true)), title: "Register as a Team Member", highlighted: true),
        button(route: .home, title: "Keep my Subscription"),
    ])
}

func teamMemberSubscribeForGiftSubscriber(signupToken: UUID) -> Node {
    return template(content: [
        .p(class: "center bold", ["You already have an active gift subscription."]),
        .p(class: "center", ["If you register as a team member now, you'll automatically stay subscribed with your team once the gift subcription expires."]),
        ], buttons: [
            button(route: .subscription(.registerAsTeamMember(token: signupToken, terminate: false)), title: "Register as a Team Member"),
        ])
}

func teamMemberSubscribeForAlreadyPartOfThisTeam() -> Node {
    return template(content: [
        .p(class: "center bold", ["You're already part of this team."]),
        .p(class: "center", ["Your account has already been linked to this team and you have full access to Swift Talk. Enjoy!"]),
    ], buttons: [])
}

func teamMemberSubscribeForSignedIn(signupToken: UUID) -> Node {
    return template(content: [
        .h3(class: "center color-blue", ["Welcome to Swift Talk!"]),
        .p(class: "center", ["To join as a team member, please confirm using the button below."]),
    ], buttons: [
        button(route: .subscription(.registerAsTeamMember(token: signupToken, terminate: false)), title: "Join as a Team Member")
    ])
}

func teamMemberSubscribe(signupToken: UUID) -> Node {
    return template(content: [
        .h3(class: "center color-blue", ["Welcome to Swift Talk!"]),
        .p(class: "center", ["You’ve been invited to join Swift Talk as a team member. Please start by logging in with GitHub."]),
    ], buttons: [
        button(route: .login(.login(continue: .signup(.teamMember(token: signupToken)))), title: "Log in with GitHub")
    ])
}

