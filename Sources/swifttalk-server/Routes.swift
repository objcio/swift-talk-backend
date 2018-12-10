//
//  Routes.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation

enum Route: Equatable {
    case home
    case episodes
    case sitemap
    case subscribe
    case collections
    case login(continue: String?)
    case thankYou
    case githubCallback(code: String?, origin: String?)
    case collection(Id<Collection>)
    case episode(Id<Episode>, playPosition: Int?)
    case download(Id<Episode>)
    case playProgress(Id<Episode>)
    case staticFile(path: [String])
    case recurlyWebhook
    case githubWebhook
    case error
    case promoCode(String)
    case rssFeed
    case episodesJSON(showUnreleased: String?)
    case collectionsJSON(showUnreleased: String?)
    case gift(Gifts)
    case account(Account)
    case subscription(Subscription)
    
    enum Subscription: Equatable {
        case cancel
        case reactivate
        case upgrade
        case create(couponCode: String?)
        case new(couponCode: String?)
    }
   
    enum Account: Equatable {
        case register(couponCode: String?)
        case profile
        case billing
        case teamMembers
        case deleteTeamMember(UUID)
        case updatePayment
        case logout
    }
    
    enum Gifts: Equatable {
        case home
        case new
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

private let episode: Router<Route> = (Router<()>.c("episodes") / .string() / Router<String>.optionalQueryParam(name: "t")).transform({
    let playPosition = $0.1.flatMap { str in
        Int(str.trimmingCharacters(in: CharacterSet.decimalDigits.inverted))
    }
    return Route.episode(Id(rawValue: $0.0), playPosition: playPosition)
}, { r in
    guard case let .episode(num, playPosition) = r else { return nil }
    return (num.rawValue, playPosition.map { "\($0)s" })
})

private let episodesJSON: Router<Route> = (Router<()>.c("episodes.json") / Router<String>.optionalQueryParam(name: "show_unreleased")).transform({ Route.episodesJSON(showUnreleased: $0) }, { r in
    guard case let .episodesJSON(x) = r else { return nil }
    return x
})

private let collectionsJSON: Router<Route> = (Router<()>.c("collections.json") / Router<String>.optionalQueryParam(name: "show_unreleased")).transform({ Route.collectionsJSON(showUnreleased: $0) }, { r in
    guard case let .collectionsJSON(x) = r else { return nil }
    return x
})

private let episodeDownload: Router<Route> = (Router<()>.c("episodes") / .string() / Router<()>.c("download")).transform({ Route.download(Id(rawValue: $0.0)) }, { r in
    guard case let .download(num) = r else { return nil }
    return (num.rawValue, ())
})

private let episodePlayProgress: Router<Route> = (Router<()>.c("episodes") / .string() / Router<()>.c("play-progress")).transform({ Route.playProgress(Id(rawValue: $0.0)) }, { r in
    guard case let .playProgress(num) = r else { return nil }
    return (num.rawValue, ())
})

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

private let loginRoute: Router<Route> = (.c("users") / .c("auth") / .c("github") / Router.optionalQueryParam(name: "origin")).transform({ Route.login(continue: $0)}, { r in
    guard case .login(let x) = r else { return nil }
    return x
})



private let deleteTeamMember: Router<Route> = (Router<()>.c("team_members") / .c("delete") / Router.uuid).transform({ Route.account(.deleteTeamMember($0))}, { r in
    guard case let .account(.deleteTeamMember(id)) = r else { return nil }
    return id
})

private let externalRoutes: [Router<Route>] = [
    Router(.home),
    .c("sitemap", .sitemap)
]

private let register: Router<Route> = .c("register") / Router.optionalString().transform({ Route.account(.register(couponCode: $0)) }, { (route: Route) -> String?? in
    guard case let Route.account(.register(x)) = route else { return nil }
    return x
})

private let accountRoutes: [Router<Route>] = [
    callbackRoute,
    loginRoute,
    .c("account") / [
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
    .c("new") / Router.optionalString().transform(Route.Subscription.new, { route in
        guard case let .new(x) = route else { return nil }
        return x
    }),
    .c("cancel", .cancel),
    .c("reactivate", .reactivate),
    .c("upgrade", .upgrade),
    Router.optionalString().transform(Route.Subscription.create, { r in
        guard case let .create(s) = r else { return nil }
        return s
    }),
]

private let subscriptionRoutes: [Router<Route>] = [
    .c("subscribe", .subscribe),
    .c("subscription") / subscriptionRoutes2.choice().transform(Route.subscription, { r in
        guard case let .subscription(x) = r else { return nil }
        return x
    }),
    .c("thankYou", .thankYou),
]

private let otherRoutes: [Router<Route>] = [
    .c("episodes", .episodes),
    assetsRoute,
    .c("favicon.ico", Route.staticFile(path: ["favicon.ico"])),
    .c("collections", .collections),
    episodeDownload,
    episodePlayProgress,
    episode,
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
    episodesJSON,
    collectionsJSON
]

private let giftRoutes: [Router<Route.Gifts>] = [
    Router(.home),
    .c("new", .new),
    Router.uuid.transform({ .pay($0) }, { r in
        guard case let .pay(x) = r else { return nil }
        return x
    }),
    .c("redeem") / Router.uuid.transform({ .redeem($0) }, { r in
        guard case let .redeem(x) = r else { return nil }
        return x
    }),
    .c("thankYou") / Router.uuid.transform({ .thankYou($0) }, { r in
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

