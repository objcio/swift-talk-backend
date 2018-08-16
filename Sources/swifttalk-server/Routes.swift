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
    case login
    case logout
    case githubCallback(String)
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

let callbackRoute: Route<MyRoute> = .c("users") / .c("auth") / .c("github") / .c("callback") / (Route<String>.queryParam(name: "code").transform({ MyRoute.githubCallback($0) }, { r in
    guard case let .githubCallback(x) = r else { return nil }
    return x
}))

let assetsRoute: Route<MyRoute> = (.c("assets") / .path()).transform({ MyRoute.staticFile(path:$0) }, { r in
    guard case let .staticFile(path) = r else { return nil }
    return path
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
    .c("users") / .c("auth") / .c("github", .login),
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
