//
//  Routes.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation

enum Route: Equatable {
    case home
    case books
    case issues
    case episodes
    case sitemap
    case imprint
    case subscribe
    case register
    case collections
    case login(continue: String?)
    case logout
    case thankYou
    case createSubscription // .subscription(.create) (TODO should be a post)
    case newSubscription // .subscription(.new)
    case accountProfile // account(.profile)
    case accountBilling // account(.billing)
    case accountTeamMembers
    case accountDeleteTeamMember(UUID)
    case githubCallback(String, origin: String?)
    case collection(Id<Collection>)
    case episode(Id<Episode>)
    case download(Id<Episode>)
    case staticFile(path: [String])
    case external(URL)
    case recurlyWebhook
    case githubWebhook
    case error
    case cancelSubscription
    case reactivateSubscription
    case scheduledTask
    case upgradeSubscription
    case accountUpdatePayment
}

extension Route {
    var path: String {
        guard let result = router.print(self)?.prettyPath else {
            log(error: "Couldn't print path for \(self) \(String(describing: router.print(self)))")
            return ""
        }
        return result
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

func inWhitelist(_ path: [String]) -> Bool {
    return !path.contains("..")
}


private extension Array where Element == Router<Route> {
    func choice() -> Router<Route> {
        assert(!isEmpty)
        return dropFirst().reduce(self[0], { $0.or($1) })
    }
}

private let episode: Router<Route> = (Router<()>.c("episodes") / .string()).transform({ Route.episode(Id(rawValue: $0)) }, { r in
    guard case let .episode(num) = r else { return nil }
    return num.rawValue
})

private let episodeDownload: Router<Route> = (Router<()>.c("episodes") / .string() / Router<()>.c("download")).transform({ Route.download(Id(rawValue: $0.0)) }, { r in
    guard case let .download(num) = r else { return nil }
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

private let createSubRoute: Router<Route> = .c("subscription", .createSubscription)

private let externalRoute: Router<Route> = Router.external.transform({ Route.external($0) }, { r in
    guard case let .external(url) = r else { return nil }
    return url
})

private let externalRoutes: [Router<Route>] = [
    Router(.home),
    .c("books", .books), // todo absolute url
    .c("issues", .issues), // todo absolute url
    .c("sitemap", .sitemap),
    .c("imprint", .imprint),
    externalRoute,
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
    .c("registration", .register),
    .c("subscription") / .c("new", .newSubscription),
    .c("subscription") / .c("cancel", .cancelSubscription),
    .c("subscription") / .c("reactivate", .reactivateSubscription),
    .c("subscription") / .c("upgrade", .upgradeSubscription),
    createSubRoute,
    .c("thankYou", .thankYou),
]

private let otherRoutes: [Router<Route>] = [
    .c("episodes", .episodes),
    assetsRoute,
    .c("collections", .collections),
    episodeDownload,
    episode,
    collection,
]

private let internalRoutes: [Router<Route>] = [
    .c("hooks") / .c("recurly", .recurlyWebhook),
    .c("hooks") / .c("github", .githubWebhook),
    .c("process_tasks", .scheduledTask)
]

let allRoutes = externalRoutes + accountRoutes + subscriptionRoutes + otherRoutes + internalRoutes
private let router = allRoutes.choice()

