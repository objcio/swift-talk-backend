//
//  Routes.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation

indirect enum Route: Equatable {
    case home
    case episodes
    case sitemap
    case subscribe
    case subscribeTeam
    case teamMemberSignup(token: UUID)
    case collections
    case login(continue: Route?, couponCode: String?, team: Bool)
    case loginWithGithub(continue: Route?)
    case forgotPassword
    case githubCallback(code: String?, origin: String?)
    case collection(Id<Collection>)
    case staticFile(path: [String])
    case recurlyWebhook
    case githubWebhook
    case error
    case promoCode(String)
    case rssFeed
    case episodesJSON
    case collectionsJSON
    case episode(Id<Episode>, EpisodeR)
    case gift(Gifts)
    case account(Account)
    case subscription(Subscription)
    
    enum EpisodeR: Equatable {
        case download
        case view(playPosition: Int?)
        case playProgress
    }
    
    enum Subscription: Equatable {
        case cancel
        case reactivate
        case upgrade
        case create(couponCode: String?, team: Bool)
        case new(couponCode: String?, team: Bool)
        case teamMember(token: UUID)
    }
   
    enum Account: Equatable {
        case register(couponCode: String?, team: Bool)
        case thankYou
        case profile
        case billing
        case teamMembers
        case deleteTeamMember(UUID)
        case updatePayment
        case logout
    }
    
    enum Gifts: Equatable {
        case home
        case new(planCode: String)
        case pay(UUID)
        case redeem(UUID)
        case thankYou(UUID)
    }
}


extension Route {
    var path: String {
        guard let result = router.print(self)?.prettyPath else {
            log(error: "Couldn't print path for \(self) \(String(describing: router.print(self)))")
            return ""
        }
        return result
    }
    
    var url: URL {
        return env.baseURL.appendingPathComponent(path)
    }
    
    static var siteMap: String {
        return router.description.pretty
    }
    
    init?(_ request: Request) {
        guard let route = router.route(for: request) else { return nil }
        self = route
    }
    
    var loadSession: Bool {
        switch self {
        case .staticFile: return false
        default: return true
        }
    }
}

private extension Array where Element == Router<Route.Subscription> {
    func choice() -> Router<Route.Subscription> {
        assert(!isEmpty)
        return dropFirst().reduce(self[0], { $0.or($1) })
    }
}

private extension Array where Element == Router<Route.EpisodeR> {
    func choice() -> Router<Route.EpisodeR> {
        assert(!isEmpty)
        return dropFirst().reduce(self[0], { $0.or($1) })
    }
}


private extension Array where Element == Router<Route.Gifts> {
    func choice() -> Router<Route.Gifts> {
        assert(!isEmpty)
        return dropFirst().reduce(self[0], { $0.or($1) })
    }
}

private extension Array where Element == Router<Route> {
    func choice() -> Router<Route> {
        assert(!isEmpty)
        return dropFirst().reduce(self[0], { $0.or($1) })
    }
}

extension Router where A == UUID {
    static let uuid: Router<UUID> = Router<String>.string().transform({ return UUID(uuidString: $0)}, { uuid in
        return uuid.uuidString
    })
}

extension Router where A == Id<Episode> {
    static let episodeId: Router<Id<Episode>> = Router<String>.string().transform({ return Id(rawValue: $0)}, { id in
        return id.rawValue
    })

}

private let episodeHelper: [Router<Route.EpisodeR>] = [
    Router<String>.optionalQueryParam(name: "t").transform({ str in
        let playPosition = str.flatMap { str in
            Int(str.trimmingCharacters(in: CharacterSet.decimalDigits.inverted))
        }
        return .view(playPosition: playPosition)
    }, { r in
        guard case let .view(t) = r else { return nil }
        return t.map { "\($0)s" } ?? .some(nil)
    }),
    .c("download", .download),
    .c("play-progress", .playProgress)
]

private let collection: Router<Route> = (Router<()>.c("collections") / .string()).transform({ Route.collection(Id(rawValue: $0)) }, { r in
    guard case let .collection(name) = r else { return nil }
    return name.rawValue
})

private let callbackRoute: Router<Route> = .c("users") / .c("auth") / .c("github") / .c("callback") / ((Router.optionalQueryParam(name: "code") / Router.optionalQueryParam(name: "origin")).transform({ Route.githubCallback(code: $0.0, origin: $0.1) }, { r in
    guard case let .githubCallback(x, y) = r else { return nil }
    return (x,y)
}))

private let assetsRoute: Router<Route> = (.c("assets") / .path()).transform({ Route.staticFile(path:$0) }, { r in
    guard case let .staticFile(path) = r else { return nil }
    return path
})

private let githubLoginRoute: Router<Route> = (.c("users") / .c("auth") / .c("github") / Router.optionalQueryParam(name: "origin")).transform({ origin in Route.loginWithGithub(continue: origin.flatMap { router.route(forURI: $0) }) }, { r in
    guard case .loginWithGithub(let x) = r else { return nil }
    return x?.path
})

private let loginRoute: Router<Route> = .c("login") / (Router.optionalQueryParam(name: "origin") / Router.optionalQueryParam(name: "coupon") / Router.booleanQueryParam(name: "team")).transform({ params in
    Route.login(continue: params.0.0.flatMap { router.route(forURI: $0) }, couponCode: params.0.1, team: params.1)
}, { r in
    guard case let .login(origin, coupon, team) = r else { return nil }
    return ((origin?.path, coupon), team)
})


private let deleteTeamMember: Router<Route> = (Router<()>.c("team_members") / .c("delete") / Router.uuid).transform({ Route.account(.deleteTeamMember($0))}, { r in
    guard case let .account(.deleteTeamMember(id)) = r else { return nil }
    return id
})

private let externalRoutes: [Router<Route>] = [
    Router(.home),
    .c("sitemap", .sitemap)
]

private let register: Router<Route> = (.c("register") / Router.optionalString() / Router.booleanQueryParam(name: "team")).transform({ Route.account(.register(couponCode: $0.0, team: $0.1)) }, { route in
    guard case let Route.account(.register(couponCode, team)) = route else { return nil }
    return (couponCode, team)
})

private let accountRoutes: [Router<Route>] = [
    callbackRoute,
    githubLoginRoute,
    loginRoute,
    .c("forgot-password", .forgotPassword),
    .c("account") / [
      .c("thankYou", .account(.thankYou)),
      .c("logout", .account(.logout)),
      .c("profile", .account(.profile)),
      .c("billing", .account(.billing)),
      .c("payment", .account(.updatePayment)),
      .c("team_members", .account(.teamMembers)),
      register,
      deleteTeamMember,
    ].choice()
]

private let subscriptionRoutes2: [Router<Route.Subscription>] = [
    (.c("new") / Router.optionalString() / Router.booleanQueryParam(name: "team")).transform({ Route.Subscription.new(couponCode: $0.0, team: $0.1) }, { route in
        guard case let .new(couponCode, team) = route else { return nil }
        return (couponCode, team)
    }),
    .c("team-member") / Router.uuid.transform({ Route.Subscription.teamMember(token: $0) }, { route in
        guard case let .teamMember(token) = route else { return nil }
        return token
    }),
    .c("cancel", .cancel),
    .c("reactivate", .reactivate),
    .c("upgrade", .upgrade),
    (Router.optionalString() / Router.booleanQueryParam(name: "team")).transform({ Route.Subscription.create(couponCode: $0.0, team: $0.1) }, { r in
        guard case let .create(couponCode, team) = r else { return nil }
        return (couponCode, team)
    }),
]

private let subscriptionRoutes: [Router<Route>] = [
    .c("subscribe", .subscribe),
    .c("subscribe-team", .subscribeTeam),
    .c("team-member-signup") / Router.uuid.transform({ Route.teamMemberSignup(token: $0) }, { route in
        guard case let .teamMemberSignup(token) = route else { return nil }
        return token
    }),
    .c("subscription") / subscriptionRoutes2.choice().transform(Route.subscription, { r in
        guard case let .subscription(x) = r else { return nil }
        return x
    }),
]

private let otherRoutes: [Router<Route>] = [
    .c("episodes", .episodes),
    assetsRoute,
    .c("favicon.ico", Route.staticFile(path: ["favicon.ico"])),
    .c("collections", .collections),
    (.c("episodes") / .episodeId / episodeHelper.choice()).transform({ .episode($0.0, $0.1) }, { route in
        guard case let .episode(x,y) = route else { return nil }
        return (x,y)
    }),
    collection,
    giftRoute,
    .c("episodes.rss", .rssFeed),
    .c("promo") / (Router.string().transform(Route.promoCode, { r in
        guard case let .promoCode(s) = r else { return nil }
        return s
    }))
]

private let internalRoutes: [Router<Route>] = [
    .c("hooks") / [.c("recurly", .recurlyWebhook), .c("github", .githubWebhook)].choice(),
    .c("episodes.json", .episodesJSON),
    .c("collections.json", .collectionsJSON)
]

private let giftRoutes: [Router<Route.Gifts>] = [
    Router(.home),
    .c("new") / Router.string().transform({ .new(planCode: $0) }, { r in
        guard case let .new(x) = r else { return nil }
        return x
    }),
    Router.uuid.transform({ .pay($0) }, { r in
        guard case let .pay(x) = r else { return nil }
        return x
    }),
    .c("redeem") / Router.uuid.transform({ .redeem($0) }, { r in
        guard case let .redeem(x) = r else { return nil }
        return x
    }),
    .c("thank-you") / Router.uuid.transform({ .thankYou($0) }, { r in
        guard case let .thankYou(x) = r else { return nil }
        return x
    })
]

private let giftRoute: Router<Route> =
    .c("gift") / giftRoutes.choice().transform(Route.gift, { r in
        guard case let .gift(x) = r else { return nil }
        return x
    })

let allRoutes = externalRoutes + accountRoutes + subscriptionRoutes + otherRoutes + internalRoutes
let router = allRoutes.choice()

