//
//  Subscribe.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import Base
import HTML1
import WebServer
import HTML


let subscriptionBenefits: [(icon: String, name: String, description: String)] = [
    ("icon-benefit-unlock.svg", "Watch All Episodes", "A new episode every week"),
    ("icon-benefit-download.svg", "Download Episodes", "Take Swift Talk with you when you're offline"),
    ("icon-benefit-support.svg", "Support Us", "With your help we can keep producing new episodes"),
]


func benefits(_ items: [(icon: String, name: String, description: String)]) -> Node {
    return .ul(class: "lh-110 text-center cols max-width-9 center mb- pv++ m-|stack+", items.map { b in
        .li(class: "m+|col m+|width-1/3", [
            .div(class: "color-orange", [
                .inlineSvg(class: "svg-fill-current", path: b.icon)
            ]),
            .div([
                .h3(class: "bold color-blue mt- mb---", [.text(b.name)]),
                .p(class: "color-gray-50 lh-125", [.text(b.description)])
            ])
        ])
    })
}

struct ProfileFormData {
    var email: String
    var name: String
}

func profile(submitTitle: String, action: Route) -> Form<ProfileFormData, STRequestEnvironment> {
    return Form(parse: { dict in
        guard let e = dict["email"], let n = dict["name"] else { return nil }
        return ProfileFormData(email: e, name: n)
    }, render: { data, errors in
        let form = FormView(fields: [
            .text(id: "name", title: "Name", value: data.name, note: nil),
            .text(id: "email", title: "Email", value: data.email, note: nil)
        ], submitTitle: submitTitle, action: action, errors: errors)
        return .div(form.renderStacked())
    })
}

func registerForm(couponCode: String?, planCode: String?, team: Bool) -> Form<ProfileFormData, STRequestEnvironment> {
    return profile(submitTitle: "Create Account", action: .account(.register(couponCode: couponCode, planCode: planCode, team: team))).wrap { node in
        LayoutConfig(contents: [
            .header([
                .div(class: "container-h pb+ pt-", [
                    .h1(class: "ms4 color-blue bold", ["Create Your Account"])
                ]),
            ]),
            .div(class: "container", [node])
        ]).layoutForCheckout
    }
}

fileprivate extension Plan {
    func priceBox(coupon: Coupon?, team: Bool = false) -> Node {
        let basePriceKey: KeyPath<Plan, Amount> = team ? \.teamMemberPrice : \.unit_amount_in_cents
        let price = discountedPrice(basePrice: basePriceKey, coupon: coupon)
        return .div([
            .div(class: "smallcaps-large mb-", [.text(prettyInterval)]),
            price.pretty,
            team ? .div(class: "smallcaps-large mt-", [.raw("Per Person<sup>*</sup>")]) : .none
        ])
    }
}

fileprivate func continueLink(to route: Route, title: String, extraClasses: Class? = nil) -> HTML.Node {
    return a(class: "primary-button wide-text w-button", href: route.absoluteString) { title }
}

fileprivate func continueLink(session: Session?, coupon: Coupon?, team: Bool) -> HTML.Node {
    if session.premiumAccess {
        if let d = session?.user.data, d.canceled {
            return continueLink(to: .account(.billing), title: "Reactivate Subscription", extraClasses: "c-button--ghost")
        } else {
            return continueLink(to: .account(.billing), title: "You're already subscribed", extraClasses: "c-button--ghost")
        }
    } else if session?.user != nil {
        return continueLink(to: .subscription(.new(couponCode: coupon?.coupon_code, planCode: nil, team: team)), title: "Proceed to payment")
    } else {
        return continueLink(to: .login(.login(continue: Route.subscription(.new(couponCode: coupon?.coupon_code, planCode: nil, team: team)))), title: "Sign in with Github")
    }
}

func renderSubscribe(monthly: Plan, yearly: Plan, coupon: Coupon? = nil) -> Node {
    return .withInput { env in
        let session = env.session
        let content = div(class: "purchase-subscription-container") {
            div(class: "purchase-subscription-header") {
                h2(class: "h2 center dark") {
                    "Support Swift Talks with a subscription"
                }
                div(class: "p2 center dark") {
                    "Get access to our entire archive of Swift Talks. Download videos for offline viewing."
                }
            }
            div(class: "purchase-subscriptions-details") {
                div(class: "purchase-subscriptions-container") {
                    let monthlyPrice = monthly.discountedPrice(basePrice: \.unit_amount_in_cents, coupon: coupon)
                    let yearlyPrice = yearly.discountedPrice(basePrice: \.unit_amount_in_cents, coupon: coupon)
                    let specialDeal = div {
                        if let c = coupon {
                            div(class: "caption-text-capitalised") {
                                "special deal"
                            }
                            if !c.description.isEmpty {
                                div(class: "caption-text-capitalised") {
                                    br()
                                    c.description
                                }
                            }
                        }
                    }
                    div(class: "subscription-container purchase") {
                        div(class: "purchase-subscription-content") {
                            div(class: "purchase-subscription-price-container") {
                                specialDeal
                                h1(class: "h1 center dark") { monthlyPrice.plainText }
                                div(class: "caption-text-capitalised") { "Per month" }
                            }
                            div(class: "button-container subscribe") {
                                continueLink(session: session, coupon: coupon, team: false)
                            }
                        }
                    }
                    div(class: "subscription-container purchase") {
                        div(class: "purchase-subscription-content") {
                            div(class: "purchase-subscription-price-container") {
                                specialDeal
                                h1(class: "h1 center dark") { yearlyPrice.plainText }
                                div(class: "caption-text-capitalised") { "Per year" }
                            }
                            div(class: "button-container subscribe") {
                                continueLink(session: session, coupon: coupon, team: false)
                            }
                        }
                        div(class: "subscription-savings-absolute-container") {
                            div(class: "caption-text small") {
                                let diff = Amount(usdCents: monthlyPrice.usdCents * 12 - yearlyPrice.usdCents)
                                "Save \(diff.plainText)"
                            }
                        }
                    }
                    a(class: "primary-button mobile-subscribe w-button", href: "#") {
                        "Subscribe"
                    }
                }
                div(class: "subscription-features-container") {
                    div(class: "subscription-feature") {
                        div(class: "subscription-feature-content") {
                            div(class: "subscription-feature-image-container") {
                                img(alt: "", class: "image-26", loading: "lazy", src: "/assets/images/padlock.png", width: "19")
                            }
                            div(class: "subscription-feature-details") {
                                h5(class: "h5 dark center") {
                                    "Watch all episodes"
                                }
                                div(class: "body small _75-white center") {
                                    "A new episode every week"
                                }
                            }
                        }
                    }
                    div(class: "subscription-feature") {
                        div(class: "subscription-feature-content") {
                            div(class: "subscription-feature-image-container") {
                                img(alt: "", class: "image-24", loading: "lazy", src: "/assets/images/arrow-down-swift-talks.png", width: "19")
                            }
                            div(class: "subscription-feature-details") {
                                h5(class: "h5 dark center") {
                                    "Download episodes"
                                }
                                div(class: "body small _75-white center") {
                                    "Take Swift Talk with you when you're offline"
                                }
                            }
                        }
                    }
                    div(class: "subscription-feature") {
                        div(class: "subscription-feature-content") {
                            div(class: "subscription-feature-image-container") {
                                img(alt: "", class: "image-25", loading: "lazy", src: "/assets/images/heart.png", width: "19")
                            }
                            div(class: "subscription-feature-details") {
                                h5(class: "h5 dark center") {
                                    "Support us"
                                }
                                div(class: "body small _75-white center") {
                                    "With your help we can keep producing new episodes"
                                }
                            }
                        }
                    }
                }
                div(class: "purchase-team-subscription-container") {
                    div(class: "purchase-team-subscription-content") {
                        h1(class: "h4 dark center") {
                            "Team subscription"
                        }
                        div(class: "body large center _75-opacity") {
                            "Our team subscription includes a 30% discount and comes with a central account that lets you manage billing and access for your entire team."
                        }
                    }
                    a(class: "purchase-team-subscription-button w-button", href: Route.signup(.subscribeTeam).absoluteString) {
                        "Learn more about team subscriptions"
                    }
                }
            }
        }.asOldNode
        return LayoutConfig(pageTitle: "Subscribe", contents: [content]).layout
    }
}

func renderSubscribeTeam(monthly: Plan, yearly: Plan, coupon: Coupon? = nil) -> Node {
    return .withInput { env in
        let session = env.session
        let content = div(class: "purchase-subscription-container") {
            div(class: "purchase-subscription-header") {
                h2(class: "h2 center dark") {
                    "Swift Talk Subscriptions for Teams"
                }
                div(class: "p2 center dark") {
                    "Provide access to the entire archive of Swift Talk for your team, centrally managed and billed."
                }
            }
            div(class: "purchase-subscriptions-details") {
                div(class: "purchase-subscriptions-container") {
                    let monthlyPrice = monthly.discountedPrice(basePrice: \.teamMemberPrice, coupon: coupon)
                    let yearlyPrice = yearly.discountedPrice(basePrice: \.teamMemberPrice, coupon: coupon)
                    let specialDeal = div {
                        if let c = coupon {
                            div(class: "caption-text-capitalised") {
                                "special deal"
                            }
                            if !c.description.isEmpty {
                                div(class: "caption-text-capitalised") {
                                    br()
                                    c.description
                                }
                            }
                        }
                    }
                    div(class: "subscription-container purchase") {
                        div(class: "purchase-subscription-content") {
                            div(class: "purchase-subscription-price-container") {
                                specialDeal
                                h1(class: "h1 center dark") { monthlyPrice.plainText }
                                div(class: "caption-text-capitalised") { "Per month/person" }
                            }
                            div(class: "button-container subscribe") {
                                continueLink(session: session, coupon: coupon, team: true)
                            }
                        }
                    }
                    div(class: "subscription-container purchase") {
                        div(class: "purchase-subscription-content") {
                            div(class: "purchase-subscription-price-container") {
                                specialDeal
                                h1(class: "h1 center dark") { yearlyPrice.plainText }
                                div(class: "caption-text-capitalised") { "Per year/person" }
                            }
                            div(class: "button-container subscribe") {
                                continueLink(session: session, coupon: coupon, team: true)
                            }
                        }
                        div(class: "subscription-savings-absolute-container") {
                            div(class: "caption-text small") {
                                let diff = Amount(usdCents: monthlyPrice.usdCents * 12 - yearlyPrice.usdCents)
                                "Save \(diff.plainText)"
                            }
                        }
                    }
                    a(class: "primary-button mobile-subscribe w-button", href: "#") {
                        "Subscribe"
                    }
                }
                div(class: "subscription-features-container") {
                    div(class: "subscription-feature") {
                        div(class: "subscription-feature-content") {
                            div(class: "subscription-feature-image-container") {
                                img(alt: "", class: "image-26", loading: "lazy", src: "/assets/images/padlock.png", width: "19")
                            }
                            div(class: "subscription-feature-details") {
                                h5(class: "h5 dark center") {
                                    "Watch all episodes"
                                }
                                div(class: "body small _75-white center") {
                                    "A new episode every week"
                                }
                            }
                        }
                    }
                    div(class: "subscription-feature") {
                        div(class: "subscription-feature-content") {
                            div(class: "subscription-feature-image-container") {
                                img(alt: "", class: "image-25", loading: "lazy", src: "/assets/images/heart.png", width: "19")
                            }
                            div(class: "subscription-feature-details") {
                                h5(class: "h5 dark center") {
                                    "Team manager account"
                                }
                                div(class: "body small _75-white center") {
                                    "A central account to manage billing and team members"
                                }
                            }
                        }
                    }
                    div(class: "subscription-feature") {
                        div(class: "subscription-feature-content") {
                            div(class: "subscription-feature-image-container") {
                                img(alt: "", class: "image-24", loading: "lazy", src: "/assets/images/arrow-down-swift-talks.png", width: "19")
                            }
                            div(class: "subscription-feature-details") {
                                h5(class: "h5 dark center") {
                                    "Download episodes"
                                }
                                div(class: "body small _75-white center") {
                                    "Take Swift Talk with you when you're offline"
                                }
                            }
                        }
                    }
                }
            }
        }.asOldNode
        return LayoutConfig(pageTitle: "Subscribe Team", contents: [content]).layout
    }
}

fileprivate func smallPrint(_ lines: [Node]) -> Node {
    return .ul(class: "stack pl", lines.map { .li([$0])})
}

func newSub(coupon: Coupon?, team: Bool, plans: [Plan], error: RecurlyError? = nil) throws -> Node {
    let data = SubscriptionFormData(plans: plans, selectedPlan: plans[0], team: team, coupon: coupon, error: error)
    return LayoutConfig(contents: [
        .header([
            .div(class: "container-h pb+ pt+", [
                .h1(class: "ms4 color-blue bold", ["Subscribe to Swift Talk"])
            ])
        ]),
        subscriptionForm(data, action: .subscription(.create(couponCode: coupon?.coupon_code, team: team)))
    ], includeRecurlyJS: true).layoutForCheckout
}

