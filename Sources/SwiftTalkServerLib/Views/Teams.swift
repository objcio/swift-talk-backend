//
//  Teams.swift
//  Bits
//
//  Created by Florian Kugler on 10-01-2019.
//

import Foundation

fileprivate let signupHeader = pageHeader(.other(header: "Team Member Signup", blurb: nil, extraClasses: "ms4"), extraClasses: "text-center")

fileprivate func template(content: [Node], buttons: [Node]) -> Node {
    return LayoutConfig(pageTitle: "Redeem Your Gift", contents: [
        signupHeader,
        .section(classes: "container", [
            .div(classes: "text-center center max-width-8", [
                .div(classes: "c-text", content),
                .div(classes: "mt++", buttons)
            ])
        ])
    ]).layout
}

fileprivate func button(route: Route, title: String, highlighted: Bool = false) -> Node {
    return Node.link(to: route, classes: "mb c-button c-button--big c-button--wide " + (highlighted ? "c-button--orange" : "c-button--blue"), [.text(title)])
}

func teamMemberSubscribeForSelfSubscribed(signupToken: UUID) -> Node {
    return template(content: [
        .p(classes: "center bold", ["You already have an active subscription."]),
        .p(classes: "center", ["You can register as a team member using the orange button below. Your current individual subscription will end immediately and you will receive a refund for remainder of the current billing cycle."]),
    ], buttons: [
        button(route: .subscription(.registerAsTeamMember(token: signupToken, terminate: true)), title: "End Subscription and Become a Team Member", highlighted: true),
        button(route: .home, title: "Keep my Individual Subscription"),
    ])
}

func teamMemberSubscribeForGiftSubscriber(signupToken: UUID) -> Node {
    return template(content: [
        .p(classes: "center bold", ["You already have an active gift subscription."]),
        .p(classes: "center", ["If you register as a team member now, you'll automatically stay subscribed with your team once the gift subcription expires."]),
        ], buttons: [
            button(route: .subscription(.registerAsTeamMember(token: signupToken, terminate: false)), title: "Register as a Team Member"),
        ])
}

func teamMemberSubscribeForAlreadyPartOfThisTeam() -> Node {
    return template(content: [
        .p(classes: "center bold", ["You're already part of this team."]),
        .p(classes: "center", ["You account has already been linked to this team and you have full access to Swift Talk!"]),
    ], buttons: [])
}

func teamMemberSubscribeForSignedIn(signupToken: UUID) -> Node {
    return template(content: [
        .p(classes: "center bold", ["Welcome to Swift Talk!"]),
        .p(classes: "center", ["Please confirm to signup as a team member using the button below."]),
    ], buttons: [
        button(route: .login(continue: .subscription(.registerAsTeamMember(token: signupToken, terminate: false))), title: "Join as a Team Member Now")
    ])
}

func teamMemberSubscribe(signupToken: UUID) -> Node {
    return template(content: [
        .p(classes: "center bold", ["Welcome to Swift Talk!"]),
        .p(classes: "center", ["You've been invited to sign up for Swift Talk as a team member. Please start by logging in with GitHub."]),
    ], buttons: [
        button(route: .login(continue: .teamMemberSignup(token: signupToken)), title: "Log in with GitHub")
    ])
}

