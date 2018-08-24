//
//  Interpret.swift
//  Bits
//
//  Created by Chris Eidhof on 24.08.18.
//

import Foundation
import PostgreSQL

func catchAndDisplayError<I: Interpreter>(_ f: () throws -> I) -> I {
    do {
        return try f()
    } catch {
        log(error)
        if let e = error as? RenderingError {
            return .write(errorView(e.publicMessage), status: .internalServerError)
        } else {
            return .write(errorView("Something went wrong."), status: .internalServerError)
        }
    }
}

extension Interpreter {
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError { try cont(value) }
        })
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) throws -> Self) -> Self {
        return .withPostBody { dict in
            return catchAndDisplayError { try cont(dict) }
        }
    }
}

final class Lazy<A> {
    private let compute: () throws -> A
    private var cache: A?
    private var cleanup: (A) -> ()
    func get() throws -> A {
        if cache == nil {
            cache = try compute()
        }
        return cache! // todo throw an error?
    }
    init(_ compute: @escaping () throws -> A, cleanup: @escaping (A) -> ()) {
        self.compute = compute
        self.cleanup = cleanup
    }
    
    deinit {
        guard let c = cache else { return }
        cleanup(c)
    }
}

struct NotLoggedInError: Error { }

infix operator ?!: NilCoalescingPrecedence
func ?!<A>(lhs: A?, rhs: Error) throws -> A {
    guard let value = lhs else {
        throw rhs
    }
    return value
}

extension Route {
    func interpret<I: Interpreter>(sessionId: UUID?, connection c: Lazy<Connection>) throws -> I {
        let session: Session?
        if let sId = sessionId {
            let user = try c.get().execute(Row<UserData>.select(sessionId: sId))
            session = user.map { Session(sessionId: sId, user: $0, csrfToken: "TODO") }
        } else {
            session = nil
        }
        func requireSession() throws -> Session {
            return try session ?! NotLoggedInError()
        }

        switch self {
        case .books, .issues:
            return .notFound()
        case .collections:
            return I.write(index(Collection.all, session: session))
        case .imprint:
            return .write("TODO")
        case .thankYou:
            return .write("TODO thanks")
        case .register:
            let s = try requireSession()
            return I.withPostBody(do: { body in
                guard let result = registerForm(s).parse(body) else { throw RenderingError(privateMessage: "todo", publicMessage: "todo") }
                var u = s.user
                u.data.email = result.email
                u.data.name = result.name
                u.data.confirmedNameAndEmail = true
                try c.get().execute(u.update())
                return I.redirect(to: .newSubscription)
            })
        case .createSubscription:
            let s = try requireSession()
            return I.withPostBody { dict in
                guard let planId = dict["plan_id"], let token = dict["billing_info[token]"] else {
                    throw RenderingError(privateMessage: "Incorrect post data", publicMessage: "Something went wrong")
                }
                let plan = try plans.first(where: { $0.plan_code == planId }) ?! RenderingError.init(privateMessage: "Illegal plan: \(planId)", publicMessage: "Couldn't find the plan you selected.")
                let cr = CreateSubscription.init(plan_code: plan.plan_code, currency: "USD", coupon_code: nil, account: .init(account_code: s.user.id, email: s.user.data.email, billing_info: .init(token_id: token)))
                let req = recurly.createSubscription(cr)
                return I.onComplete(promise: URLSession.shared.load(req), do: { sub in
                    let sub_ = try sub ?! RenderingError(privateMessage: "Couldn't load create subscription URL", publicMessage: "Something went wrong, please try again.")
                    switch sub_ {
                    case .errors(let messages):
                        return try I.write(newSub(session: session, errs: messages.map { $0.message }))
                    case .success(let sub):
                        try c.get().execute(s.user.changeSubscriptionStatus(sub.state == .active))
                        // todo flash
                        return I.redirect(to: .thankYou)
                    }
                })
            }
        case .subscribe:
            return try I.write(plans.subscribe(session: session))
        case .collection(let name):
            guard let c = Collection.all.first(where: { $0.slug == name }) else {
                // todo throw
                return I.notFound("No such collection")
            }
            return .write(c.show(session: session))
        case .newSubscription:
            let s = try requireSession()
            let u = s.user
            if !u.data.confirmedNameAndEmail ||  !u.data.validEmail || !u.data.validName {
                return I.write(registerForm(s).0(RegisterFormData(email: u.data.email, name: u.data.name)))
            } else {
                return try I.write(newSub(session: session, errs: []))
            }
        case .login(let cont):
            // todo take cont into account
            var path = "https://github.com/login/oauth/authorize?scope=user:email&client_id=\(Github.clientId)"
            if let c = cont {
                let baseURL = env["BASE_URL"]
                let encoded = baseURL + Route.githubCallback("", origin: c).path
                path.append("&redirect_uri=" + encoded.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
            }
            return I.redirect(path: path)
        case .logout:
            let s = try requireSession()
            try c.get().execute(s.user.deleteSession(s.sessionId))
            return I.redirect(to: .home)
        case .githubCallback(let code, let origin):
            return I.onComplete(promise:
                URLSession.shared.load(Github.getAccessToken(code)).map({ $0?.access_token })
                , do: { token in
                    let t = try token ?! RenderingError(privateMessage: "No github access token", publicMessage: "Couldn't access your Github profile.")
                    return I.onComplete(promise: URLSession.shared.load(Github(t).profile), do: { profile in
                        let p = try profile ?! RenderingError(privateMessage: "Couldn't load Github profile", publicMessage: "Couldn't access your Github profile.")
                        // todo ask for email if we don't get it
                        let uid: UUID
                        if let user = try c.get().execute(Row<UserData>.select(githubId: p.id)) {
                            uid = user.id
                        } else {
                            let userData = UserData(email: p.email ?? "no email", githubUID: p.id, githubLogin: p.login, githubToken: t, avatarURL: p.avatar_url, name: p.name ?? "")
                            uid = try c.get().execute(userData.insert)
                        }
                        let sid = try c.get().execute(SessionData(userId: uid).insert)
                        let destination: String
                        if let o = origin?.removingPercentEncoding, o.hasPrefix("/") {
                            destination = o
                        } else {
                            destination = "/"
                        }
                        return I.redirect(path: destination, headers: ["Set-Cookie": "sessionid=\"\(sid.uuidString)\"; HttpOnly; Path=/"]) // TODO secure, TODO return to where user came from
                    })
            })
        case .episode(let s):
            guard let ep = Episode.all.first(where: { $0.slug == s}) else {
                return .notFound("No such episode")
            }
            return .write(ep.show(session: session))
        case .episodes:
            return I.write(index(Episode.all.filter { $0.released }, session: session))
        case .home:
            return .write(renderHome(session: session), status: .ok)
        case .sitemap:
            return .write(Route.siteMap)
        case let .staticFile(path: p):
            // todo: we're creating a database connection for every static file!
            guard inWhitelist(p) else {
                return .write("forbidden", status: .forbidden)
            }
            let name = p.map { $0.removingPercentEncoding ?? "" }.joined(separator: "/")
            return .writeFile(path: name)
        case .accountBilling:
            return .write("TODO")
        }
    }
}
