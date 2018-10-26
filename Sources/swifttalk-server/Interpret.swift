//
//  Interpret.swift
//  Bits
//
//  Created by Chris Eidhof on 24.08.18.
//

import Foundation
import PostgreSQL

extension Row where Element == UserData {
    var monthsOfActiveSubscription: Promise<UInt?> {
        return recurly.subscriptionStatus(for: self.id).map { status in
            guard let s = status else { log(error: "Couldn't fetch subscription status for user \(self.id) from Recurly"); return nil }
            return s.months
        }
    }
}

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

struct NotLoggedInError: Error { }

infix operator ?!: NilCoalescingPrecedence
func ?!<A>(lhs: A?, rhs: Error) throws -> A {
    guard let value = lhs else {
        throw rhs
    }
    return value
}

struct Context {
    var path: String
    var session: Session?
}

struct VimeoID: Codable {
    var id: Int
    var name: String
    var number: Int {
        let exp = try! NSRegularExpression(pattern: "^\\d+", options: [])
        let result = exp.matches(in: name, options: [], range: NSRange(name.startIndex..<name.endIndex, in: name)).first!
        return Int(name[Range(result.range, in: name)!])!
    }
    var isPreview: Bool {
        return name.lowercased().contains("preview")
    }
}

extension Route {
    func interpret<I: Interpreter>(sessionId: UUID?, connection c: Lazy<Connection>) throws -> I {
        let session: Session?
        if self.loadSession, let sId = sessionId {
            let user = try c.get().execute(Row<UserData>.select(sessionId: sId))
            session = user.map { Session(sessionId: sId, user: $0, csrfToken: "TODO") }
        } else {
            session = nil
        }
        func requireSession() throws -> Session {
            return try session ?! NotLoggedInError()
        }
        
        let context = Context(path: path, session: session)

        switch self {
        case .books, .issues:
            return .notFound()
        case .collections:
            return I.write(index(Collection.all.filter { !$0.episodes(for: session?.user.data).isEmpty }, context: context))
        case .imprint:
            return .write("TODO")
        case .thankYou:
            return .write("TODO thanks")
        case .register:
            let s = try requireSession()
            return I.withPostBody(do: { body in
                guard let result = registerForm(context).parse(body) else { throw RenderingError(privateMessage: "todo", publicMessage: "todo") }
                var u = s.user
                u.data.email = result.email
                u.data.name = result.name
                u.data.confirmedNameAndEmail = true
                let errors = u.data.validate()
                if errors.isEmpty {
                    try c.get().execute(u.update())
                    return I.redirect(to: .newSubscription)
                } else {
                    return I.write(registerForm(context).form(result, errors))
                }
            })
        case .createSubscription:
            let s = try requireSession()
            return I.withPostBody { dict in
                guard let planId = dict["plan_id"], let token = dict["billing_info[token]"] else {
                    throw RenderingError(privateMessage: "Incorrect post data", publicMessage: "Something went wrong")
                }
                let plan = try Plan.all.first(where: { $0.plan_code == planId }) ?! RenderingError.init(privateMessage: "Illegal plan: \(planId)", publicMessage: "Couldn't find the plan you selected.")
                let cr = CreateSubscription.init(plan_code: plan.plan_code, currency: "USD", coupon_code: nil, account: .init(account_code: s.user.id, email: s.user.data.email, billing_info: .init(token_id: token)))
                let req = recurly.createSubscription(cr)
                return I.onComplete(promise: URLSession.shared.load(req), do: { sub in
                    let sub_ = try sub ?! RenderingError(privateMessage: "Couldn't load create subscription URL", publicMessage: "Something went wrong, please try again.")
                    switch sub_ {
                    case .errors(let messages):
                        return try I.write(newSub(context: context, errs: messages.map { $0.message }))
                    case .success(let sub):
                        try c.get().execute(s.user.changeSubscriptionStatus(sub.state == .active))
                        // todo flash
                        return I.redirect(to: .thankYou)
                    }
                })
            }
        case .subscribe:
            return try I.write(Plan.all.subscribe(context: context))
        case .collection(let name):
            guard let c = Collection.all.first(where: { $0.id == name }) else {
                // todo throw
                return I.notFound("No such collection")
            }
            return .write(c.show(context: context))
        case .newSubscription:
            let s = try requireSession()
            let u = s.user
            if !u.data.confirmedNameAndEmail {
                return I.write(registerForm(context).form(RegisterFormData(email: u.data.email, name: u.data.name), []))
            } else {
                return try I.write(newSub(context: context, errs: []))
            }
        case .login(let cont):
            var path = "https://github.com/login/oauth/authorize?scope=user:email&client_id=\(Github.clientId)"
            if let c = cont {
                let baseURL = env["BASE_URL"]
                let encoded = baseURL + Route.githubCallback("", origin: c).path
                print(encoded)
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
                        return I.redirect(path: destination, headers: ["Set-Cookie": "sessionid=\"\(sid.uuidString)\"; HttpOnly; Path=/"]) // TODO secure
                    })
            })
        case .episode(let id):
            guard let ep = Episode.scoped(for: session?.user.data).first(where: { $0.id == id }) else {
                return .notFound("No such episode")
            }
            let downloads = try (session?.user.downloads).map { try c.get().execute($0) } ?? []
            let status = session?.user.downloadStatus(for: ep, downloads: downloads) ?? .notSubscribed
            return .write(ep.show(downloadStatus: status, context: context))
        case .episodes:
            return I.write(index(Episode.scoped(for: session?.user.data), context: context))
        case .home:
            return .write(renderHome(context: context), status: .ok)
        case .sitemap:
            return .write(Route.siteMap)
        case .download:
            return .write("TODO")
        case let .staticFile(path: p):
            guard inWhitelist(p) else {
                return .write("forbidden", status: .forbidden)
            }
            let name = p.map { $0.removingPercentEncoding ?? "" }.joined(separator: "/")
            return .writeFile(path: name)
        case .accountBilling:
            let sess = try requireSession()
            return I.onComplete(promise: sess.user.monthsOfActiveSubscription, do: { num in
                let d = try c.get().execute(sess.user.downloads).count
                return .write("Number of months of subscription: \(num ?? 0), downloads: \(d)")
            })
        case .external(let url):
            return I.redirect(path: url.absoluteString) // is this correct?
        case .recurlyWebhook:
            return I.withPostData { data in
                guard let webhook: Webhook = try? decodeXML(from: data) else { return I.write("", status: .ok) }
                let id = webhook.account.account_code
                recurly.subscriptionStatus(for: webhook.account.account_code).run { status in
                    guard let s = status else {
                        return log(error: "Received Recurly webhook for account id \(id), but couldn't load this account from Recurly")
                    }
                    guard let r = try? c.get().execute(Row<UserData>.select(id)), var row = r else {
                        return log(error: "Received Recurly webhook for account \(id), but didn't find user in database")
                    }
                    row.data.subscriber = s.subscriber
                    row.data.downloadCredits = Int(s.months)
                    guard let _ = try? c.get().execute(row.update()) else {
                        return log(error: "Failed to update user \(id) in response to Recurly webhook")
                    }
                }
                return I.write("", status: .ok)
            }
        case .githubWebhook:
            // This could be done more fine grained, but this works just fine for now
            flushStaticData()
            return I.write("", status: .ok)
        }
    }
}
