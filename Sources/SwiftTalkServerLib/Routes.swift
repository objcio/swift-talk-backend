//
//  Routes.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation
import Routing
import Base
import WebServer

public indirect enum Route: Equatable {
    case home
    case episodes
    case collections
    case episode(Id<Episode>, EpisodeR)
    case collection(Id<Collection>)
    case sitemap
    case rssFeed
    case episodesJSON
    case collectionsJSON
    case staticFile(path: [String])
    case error
    case authorizeApp
    case gift(Gifts)
    case account(Account)
    case webhook(Webhook)
    case login(Login)
    case signup(Signup)
    case subscription(Subscription)
    case admin(Admin)

    public enum Signup: Equatable {
        case promoCode(String)
        case subscribe(planName: String?)
        case subscribeTeam
        case teamMember(token: UUID)
    }
    
    public enum Login: Equatable {
        case login(continue: Route?)
        case githubCallback(code: String?, origin: String?)
    }
    
    public enum Webhook: Equatable {
        case recurlyWebhook(String)
        case githubWebhook
    }

    public enum EpisodeR: Equatable {
        case download
        case view(playPosition: Int?)
        case playProgress
    }
    
    public enum Subscription: Equatable {
        case cancel
        case reactivate
        case upgrade
        case create(couponCode: String?, team: Bool)
        case new(couponCode: String?, planCode: String?, team: Bool)
        case registerAsTeamMember(token: UUID, terminate: Bool)
        case threeDSecureChallenge(threeDActionToken: String, recurlyToken: String, planId: String, couponCode: String?, team: Bool)
        case threeDSecureResponse(threeDResultToken: String, recurlyToken: String, planId: String, couponCode: String?, team: Bool)
    }
   
    public enum Account: Equatable {
        case register(couponCode: String?, planCode: String?, team: Bool)
        case profile
        case billing
        case teamMembers
        case deleteTeamMember(UUID)
        case invalidateTeamToken
        case updatePayment
        case logout
    }
    
    public enum Gifts: Equatable {
        case home
        case new(planCode: String)
        case pay(UUID)
        case redeem(UUID)
        case thankYou(UUID)
    }
    
    public enum Admin: Equatable {
        case home
        case users(Users)
        public enum Users: Equatable {
            case home
            case view(UUID)
            case find(String)
            case sync(UUID)
        }
    }
}

extension Route {
    public var path: String {
        guard let result = router.prettyPrint(self) else {
            log(error: "Couldn't print path for \(self))")
            return ""
        }
        return result
    }

    var url: URL {
        return env.baseURL.appendingPathComponent(path)
    }
    
    static var siteMap: String {
        return router.prettyDescription
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


private let loginRoutes: [Router<Route.Login>] = [
    Router.optionalQueryParam(name: "origin").transform({ origin in
        .login(continue: origin.flatMap {router.route(forURI: $0)})
    }, {
        guard case let .login(x) = $0 else { return nil }
        return x?.path
    }),
    .c("callback") / (Router.optionalQueryParam(name: "code") / Router.optionalQueryParam(name: "origin")).transform({
        .githubCallback(code: $0.0, origin: $0.1)
    }, {
        guard case let .githubCallback(x, y) = $0 else { return nil }
        return (x,y)
    })
]

private let loginRoute: Router<Route> = .c("users") / .c("auth") / .c("github") / choice(loginRoutes).transform(Route.login, {
    guard case let .login(x) = $0 else { return nil }
    return x
})

private let accountRoutes: [Router<Route.Account>] = [
    .c("logout", .logout),
    .c("profile", .profile),
    .c("billing", .billing),
    .c("payment", .updatePayment),
    .c("team_members", .teamMembers),
    .c("team_members") / .c("delete") / Router.uuid.transform({
        .deleteTeamMember($0)
    }, {
        guard case let .deleteTeamMember(id) = $0 else { return nil };
        return id
    }),
    .c("register") / (Router.optionalString() / Router.optionalQueryParam(name: "plan_code") / Router.booleanQueryParam(name: "team")).transform({
        .register(couponCode: $0.0.0, planCode: $0.0.1, team: $0.1)
    }, {
        guard case let .register(couponCode, planCode, team) = $0 else { return nil }
        return ((couponCode, planCode), team)
    }),
    .c("invalidate_team_token", .invalidateTeamToken)
]

private let accountRoute: Router<Route> = .c("account") / choice(accountRoutes).transform(Route.account, {
    guard case let .account(x) = $0 else { return nil }
    return x
})

private let subscriptionRoutes: [Router<Route.Subscription>] = [
    (.c("new") / Router.optionalString() / Router.optionalQueryParam(name: "plan_code") / Router.booleanQueryParam(name: "team")).transform({
        Route.Subscription.new(couponCode: $0.0.0, planCode: $0.0.1, team: $0.1)
    }, {
        guard case let .new(couponCode, planCode, team) = $0 else { return nil }
        return ((couponCode, planCode), team)
    }),
    .c("register_team_member") / (Router.uuid / Router.booleanQueryParam(name: "terminate")).transform({
        Route.Subscription.registerAsTeamMember(token: $0.0, terminate: $0.1)
    }, {
        guard case let .registerAsTeamMember(token, terminate) = $0 else { return nil }
        return (token, terminate)
    }),
    .c("cancel", .cancel),
    .c("reactivate", .reactivate),
    .c("upgrade", .upgrade),
    (Router.optionalString() / Router.booleanQueryParam(name: "team")).transform({
        Route.Subscription.create(couponCode: $0.0, team: $0.1)
    }, {
        guard case let .create(couponCode, team) = $0 else { return nil }
        return (couponCode, team)
    }),
    .c("three_d_secure_challenge") / (Router.string() / Router.queryParam(name: "recurly_token") / Router.queryParam(name: "plan_id") / Router.optionalQueryParam(name: "coupon_code") / Router.booleanQueryParam(name: "team")).transform({
        Route.Subscription.threeDSecureChallenge(threeDActionToken: $0.0.0.0.0, recurlyToken: $0.0.0.0.1, planId: $0.0.0.1, couponCode: $0.0.1, team: $0.1)
    }, {
        guard case let .threeDSecureChallenge(threeDActionToken, recurlyToken, planId, couponCode, team) = $0 else { return nil }
        return ((((threeDActionToken, recurlyToken), planId), couponCode), team)
    }),
    .c("three_d_secure_response") / (Router.string() / Router.queryParam(name: "recurly_token") / Router.queryParam(name: "plan_id") / Router.optionalQueryParam(name: "coupon_code") / Router.booleanQueryParam(name: "team")).transform({
        Route.Subscription.threeDSecureResponse(threeDResultToken: $0.0.0.0.0, recurlyToken: $0.0.0.0.1, planId: $0.0.0.1, couponCode: $0.0.1, team: $0.1)
    }, {
        guard case let .threeDSecureResponse(threeDResultToken, recurlyToken, planId, couponCode, team) = $0 else { return nil }
        return ((((threeDResultToken, recurlyToken), planId), couponCode), team)
    }),
]

private let subscriptionRoute: Router<Route> = .c("subscription") / choice(subscriptionRoutes).transform(Route.subscription, {
    guard case let .subscription(x) = $0 else { return nil }
    return x
})

private let signupRoutes: [Router<Route.Signup>] = [
    .c("subscribe") / Router.optionalString().transform(Route.Signup.subscribe, {
        guard case let .subscribe(s) = $0 else { return nil }
        return s
    }),
    .c("subscribe_team", .subscribeTeam),
    .c("team_member_signup") / Router.uuid.transform({ .teamMember(token: $0) }, {
        guard case let .teamMember(token) = $0 else { return nil }
        return token
    }),
    .c("promo") / Router.string().transform(Route.Signup.promoCode, {
        guard case let .promoCode(s) = $0 else { return nil }
        return s
    })
]

private let signupRoute: Router<Route> = choice(signupRoutes).transform(Route.signup, {
    guard case let .signup(x) = $0 else { return nil }
    return x
})

private let episodeRoutes: [Router<Route.EpisodeR>] = [
    Router<String>.optionalQueryParam(name: "t").transform({ param in
        let playPosition = param.flatMap {
            Int($0.trimmingCharacters(in: CharacterSet.decimalDigits.inverted))
        }
        return .view(playPosition: playPosition)
    }, {
        guard case let .view(t) = $0 else { return nil }
        return t.map { "\($0)s" } ?? .some(nil)
    }),
    .c("download", .download),
    .c("play-progress", .playProgress)
]

extension Router where A == Id<Episode> {
    static let episodeId: Router<Id<Episode>> = Router<String>.string().transform({ return Id(rawValue: $0)}, { id in
        return id.rawValue
    })
}

private let episodeRoute: Router<Route> = .c("episodes") / (.episodeId / choice(episodeRoutes)).transform({
    .episode($0.0, $0.1)
}, {
    guard case let .episode(x,y) = $0 else { return nil }
    return (x, y)
})

private let webhookRoutes: [Router<Route.Webhook>] = [
    .c("recurly") / Router.string().transform({.recurlyWebhook($0)}, {
        guard case let .recurlyWebhook(x) = $0 else { return nil }
        return x
    }),
    .c("github", .githubWebhook)
]

private let webhookRoute: Router<Route> = .c("hooks") / choice(webhookRoutes).transform(Route.webhook, {
    guard case let .webhook(x) = $0 else { return nil }
    return x
})

private let giftRoutes: [Router<Route.Gifts>] = [
    Router(.home),
    .c("new") / Router.string().transform({ .new(planCode: $0) }, {
        guard case let .new(x) = $0 else { return nil }
        return x
    }),
    Router.uuid.transform({ .pay($0) }, {
        guard case let .pay(x) = $0 else { return nil }
        return x
    }),
    .c("redeem") / Router.uuid.transform({ .redeem($0) }, {
        guard case let .redeem(x) = $0 else { return nil }
        return x
    }),
    .c("thank-you") / Router.uuid.transform({ .thankYou($0) }, {
        guard case let .thankYou(x) = $0 else { return nil }
        return x
    })
]



private let giftRoute: Router<Route> = .c("gift") / choice(giftRoutes).transform(Route.gift, {
    guard case let .gift(x) = $0 else { return nil }
    return x
})

private let adminUserRoutes: [Router<Route.Admin.Users>] = [
    Router(.home),
    Router.uuid.transform({ .view($0) }, {
        guard case let .view(x) = $0 else { return nil }
        return x
    }),
    .c("find") / Router.string().transform({ .find($0) }, {
        guard case let .find(x) = $0 else { return nil }
        return x
    }),
    .c("sync") / Router.uuid.transform({ .sync($0) }, {
        guard case let .sync(x) = $0 else { return nil }
        return x
    }),
]


private let adminRoutes: [Router<Route.Admin>] = [
    Router(.home),
    .c("users") / choice(adminUserRoutes).transform(Route.Admin.users, {
        guard case let .users(x) = $0 else { return nil }
        return x
    })
]

private let adminRoute: Router<Route> = .c("admin") / choice(adminRoutes).transform(Route.admin, {
    guard case let .admin(x) = $0 else { return nil }
    return x
})

private let generalRoutes: [Router<Route>] = [
    Router(.home),
    .c("episodes", .episodes),
    .c("collections", .collections),
    .c("collections") / Router.string().transform({ Route.collection(Id(rawValue: $0)) }, {
        guard case let .collection(name) = $0 else { return nil }
        return name.rawValue
    }),
    .c("assets") / Router.path().transform({ Route.staticFile(path: $0) }, {
        guard case let .staticFile(path) = $0 else { return nil }
        return path
    }),
    .c("favicon.ico", Route.staticFile(path: ["favicon.ico"])),
    .c("episodes.rss", .rssFeed),
    .c("episodes.json", .episodesJSON),
    .c("collections.json", .collectionsJSON),
    .c("sitemap", .sitemap),
    .c("authorize_app", .authorizeApp),
]

private let subRoutes: [Router<Route>] = [
    episodeRoute,
    giftRoute,
    accountRoute,
    loginRoute,
    subscriptionRoute,
    signupRoute,
    webhookRoute,
    adminRoute,
]

let router = choice(generalRoutes + subRoutes)

