//
//  Routes.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation

enum MyRoute: Equatable {
    case home
    case books
    case issues
    case episodes
    case version
    case sitemap
    case imprint
    case subscribe
    case collections
    case login(continue: String?)
    case logout
    case newSubscription // .subscription(.new)
    case accountBilling // account(.billing)
    case githubCallback(String, origin: String?)
    case collection(Slug<Collection>)
    case episode(Slug<Episode>)
    case staticFile(path: [String])
}

extension Array where Element == Route<MyRoute> {
    func choice() -> Route<MyRoute> {
        assert(!isEmpty)
        return dropFirst().reduce(self[0], { $0.or($1) })
    }
}

let episode: Route<MyRoute> = (Route<()>.c("episodes") / .string()).transform({ MyRoute.episode(Slug(rawValue: $0)) }, { r in
    guard case let .episode(num) = r else { return nil }
    return num.rawValue
})

let collection: Route<MyRoute> = (Route<()>.c("collections") / .string()).transform({ MyRoute.collection(Slug(rawValue: $0)) }, { r in
    guard case let .collection(name) = r else { return nil }
    return name.rawValue
})

let callbackRoute: Route<MyRoute> = .c("users") / .c("auth") / .c("github") / .c("callback") / ((Route<String>.queryParam(name: "code") / Route.optionalQueryParam(name: "origin")).transform({ MyRoute.githubCallback($0.0, origin: $0.1) }, { r in
    guard case let .githubCallback(x, y) = r else { return nil }
    return (x,y)
}))

let assetsRoute: Route<MyRoute> = (.c("assets") / .path()).transform({ MyRoute.staticFile(path:$0) }, { r in
    guard case let .staticFile(path) = r else { return nil }
    return path
})

let loginRoute: Route<MyRoute> = (.c("users") / .c("auth") / .c("github") / Route.optionalQueryParam(name: "origin")).transform({ MyRoute.login(continue: $0)}, { r in
    guard case .login(let x) = r else { return nil }
    return x
})

let routes: Route<MyRoute> = [
    Route(.home),
    .c("version", .version),
    .c("books", .books), // todo absolute url
    .c("issues", .issues), // todo absolute url
    .c("episodes", .episodes),
    .c("sitemap", .sitemap),
    .c("subscribe", .subscribe),
    .c("imprint", .imprint),
    .c("subscription") / .c("new", .newSubscription),
    .c("account") / .c("billing", .accountBilling),
    loginRoute,
    .c("logout", .logout),
    callbackRoute,
    assetsRoute,
    .c("collections", .collections),
    episode,
    collection
    ].choice()

func inWhitelist(_ path: [String]) -> Bool {
    return !path.contains("..")
}
