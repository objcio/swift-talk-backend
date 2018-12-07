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
    case register(couponCode: String?)
    case collections
    case login(continue: String?)
    case logout
    case thankYou
    case createSubscription(couponCode: String?)
    case newSubscription(couponCode: String?)
    case accountProfile
    case accountBilling
    case accountTeamMembers
    case accountDeleteTeamMember(UUID)
    case githubCallback(String, origin: String?)
    case collection(Id<Collection>)
    case episode(Id<Episode>, playPosition: Int?)
    case download(Id<Episode>)
    case playProgress(Id<Episode>)
    case staticFile(path: [String])
    case recurlyWebhook
    case githubWebhook
    case error
    case cancelSubscription
    case reactivateSubscription
    case upgradeSubscription
    case accountUpdatePayment
    case promoCode(String)
    case rssFeed
    case episodesJSON(showUnreleased: String?)
    case collectionsJSON(showUnreleased: String?)
    case gift
    case newGift
    case payGift(UUID)
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

private let callbackRoute: Router<Route> = .c("users") / .c("auth") / .c("github") / .c("callback") / ((Router<String>.queryParam(name: "code") / Router.optionalQueryParam(name: "origin")).transform({ Route.githubCallback($0.0, origin: $0.1) }, { r in
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



private let deleteTeamMember: Router<Route> = (Router<()>.c("team_members") / .c("delete") / .string()).transform({
    let id = UUID(uuidString: $0)
    return id.map { Route.accountDeleteTeamMember($0) }
}, { r in
    guard case let .accountDeleteTeamMember(id) = r else { return nil }
    return id.uuidString
})

private let createSubRoute: Router<Route> = .c("subscription") / Router.optionalString().transform(Route.createSubscription, { r in
	guard case let  Route.createSubscription(s) = r else { return nil }
    return s
})

private let externalRoutes: [Router<Route>] = [
    Router(.home),
    .c("sitemap", .sitemap)
]

private let accountRoutes: [Router<Route>] = [
    callbackRoute,
    loginRoute,
    .c("logout", .logout),
    .c("account") / .c("profile", .accountProfile),
    .c("account") / .c("billing", .accountBilling),
    .c("account") / .c("payment", .accountUpdatePayment),
    deleteTeamMember,
    .c("account") / .c("team_members", .accountTeamMembers),
]

private let subscriptionRoutes: [Router<Route>] = [
    .c("subscribe", .subscribe),
    .c("registration") / Router.optionalString().transform(Route.register, { route in
        guard case let .register(x) = route else { return nil }
        return x
    }),
    .c("subscription") / .c("new") / Router.optionalString().transform(Route.newSubscription, { route in
        guard case let .newSubscription(x) = route else { return nil }
        return x
    }),
    .c("subscription") / .c("cancel", .cancelSubscription),
    .c("subscription") / .c("reactivate", .reactivateSubscription),
    .c("subscription") / .c("upgrade", .upgradeSubscription),
    createSubRoute,
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
    .c("episodes.rss", .rssFeed),
    .c("promo") / (Router.string().transform(Route.promoCode, { r in
        guard case let .promoCode(s) = r else { return nil }
        return s
    }))
]

private let internalRoutes: [Router<Route>] = [
    .c("hooks") / .c("recurly", .recurlyWebhook),
    .c("hooks") / .c("github", .githubWebhook),
    episodesJSON,
    collectionsJSON
]

private let giftRoutes: [Router<Route>] = [
    .c("gift") / .c("new", .gift),
    .c("gift") / .c("new", .newGift),
    .c("gift") / Router.uuid.transform(Route.payGift, { r in
        guard case let .payGift(x) = r else { return nil }
        return x
    })
]

let allRoutes = externalRoutes + accountRoutes + subscriptionRoutes + otherRoutes + internalRoutes + giftRoutes
let router = allRoutes.choice()

