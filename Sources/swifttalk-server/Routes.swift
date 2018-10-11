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
    case accountBilling // account(.billing)
    case githubCallback(String, origin: String?)
    case collection(Slug<Collection>)
    case episode(Slug<Episode>)
    case download(Slug<Episode>)
    case staticFile(path: [String])
    case external(URL)
    case recurlyWebhook
}

extension Route {
    var path: String {
        guard let result = router.print(self)?.prettyPath else {
            log(error: "Couldn't print path for \(self) \(router.print(self))")
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

private let episode: Router<Route> = (Router<()>.c("episodes") / .string()).transform({ Route.episode(Slug(rawValue: $0)) }, { r in
    guard case let .episode(num) = r else { return nil }
    return num.rawValue
})

private let collection: Router<Route> = (Router<()>.c("collections") / .string()).transform({ Route.collection(Slug(rawValue: $0)) }, { r in
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

private let createSubRoute: Router<Route> = .c("subscription", .createSubscription)

private let externalRoute: Router<Route> = Router.external.transform({ Route.external($0) }, { r in
    guard case let .external(url) = r else { return nil }
    return url
})

private let router: Router<Route> = [
    Router(.home),
    .c("books", .books), // todo absolute url
    .c("issues", .issues), // todo absolute url
    .c("episodes", .episodes),
    .c("sitemap", .sitemap),
    .c("subscribe", .subscribe),
    .c("imprint", .imprint),
    .c("registration", .register),
    .c("subscription") / .c("new", .newSubscription),
    createSubRoute,
    .c("account") / .c("billing", .accountBilling),
    loginRoute,
    .c("logout", .logout),
    callbackRoute,
    assetsRoute,
    .c("collections", .collections),
    episode,
    collection,
    externalRoute,
    .c("recurly", .recurlyWebhook)
].choice()

