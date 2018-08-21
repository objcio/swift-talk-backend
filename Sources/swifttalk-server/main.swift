import Foundation
import NIO
import NIOHTTP1
import PostgreSQL


var standardError = FileHandle.standardError
let env = Env()

let recurly = Recurly(subdomain: "\(env["RECURLY_SUBDOMAIN"]).recurly.com", apiKey: env["RECURLY_API_KEY"])

// TODO: I'm not sure if it's a good idea to initialize the plans like this. We should maybe also have static data?
private(set) var plans: [Plan] = []
URLSession.shared.load(recurly.plans, callback: { value in
    if let p = value {
        plans = p
    } else {
        print("Could not load plans", to: &standardError) // todo: fall back to old plans?
    }
})

// fetches mail@floriankugler.com account from recurly staging and calculates number of months with an active subscription
//let myId = UUID(uuidString: "06a5313b-7972-48a9-a0a9-3d7d741afe44")!
//URLSession.shared.load(recurly.account(with: myId)) { result in
//    guard let acc = result else { fatalError() }
//    URLSession.shared.load(recurly.listSubscriptions(accountId: acc.account_code)) { subs in
//        let months = subs?.map { $0.activeMonths }.reduce(0, +)
//        print("Months of active subscription: \(months)")
//    }
//}

func log(_ e: Error) {
    print(e.localizedDescription, to: &standardError)
}

func log(error: String) {
    print(error, to: &standardError)
}

func catchAndDisplayError<I: Interpreter>(_ f: () throws -> I) -> I {
    do {
        return try f()
    } catch {
        log(error)
        if let e = error as? RenderingError {
            return .write(e.publicMessage, status: .internalServerError)
        } else {
            return .write("Something went wrong", status: .internalServerError)
        }
    }
}

struct NoDatabaseConnection: Error { }

extension Route {
    func interpret<I: Interpreter>(sessionId: UUID?) throws -> I {
        let session: Session?
        if let sId = sessionId {
            session = withConnection { connection in
                guard let c = connection else { return nil }
                let user = tryOrPrint { try c.execute(UserResult.select(sessionId: sId)) }
                return user.map { Session(sessionId: sId, user: $0, csrfToken: "TODO") }
            }
        } else {
            session = nil
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
        case .createSubscription(let planId, let token):
            guard let plan = plans.first(where: { $0.plan_code == planId }) else {
                throw RenderingError.init(privateMessage: "Illegal plan: \(planId)", publicMessage: "Couldn't find the plan you selected.")
            }
            guard let u = session?.user else {
                throw RenderingError(privateMessage: "Creating subscription without user", publicMessage: "You're not logged in.")
            }
            let c = CreateSubscription.init(plan_code: planId, currency: "USD", coupon_code: nil, account: .init(account_code: u.id, email: u.data.email, billing_info: .init(token_id: token)))
            let req = try recurly.createSubscription(c)
            return I.onComplete(promise: URLSession.shared.load(req), do: { sub in
                catchAndDisplayError {
                    guard let s = sub else {
                        throw RenderingError(privateMessage: "Couldn't load create subscription URL", publicMessage: "Something went wrong, please try again.")
                    }
                    switch s {
                    case .errors(let messages):
                        return try I.write(newSub(session: session, errs: messages.map { $0.message }))
                    case .success(let sub):
                        return try withConnection({ connection in
                            guard let c = connection else { throw NoDatabaseConnection() }
                            try c.execute(u.changeSubscriptionStatus(sub.state == .active))
                            return try I.write("Got a sub \(sub)")
                        })
                        
                    }
                }
            })
            
        case .subscribe:
            return try I.write(plans.subscribe(session: session))
        case .collection(let name):
            guard let c = Collection.all.first(where: { $0.slug == name }) else {
                // todo throw
                return I.notFound("No such collection")
            }
            return .write(c.show(session: session))
        case .newSubscription:
            // todo check that we have a valid email address, otherwise we'll fail when we create the subscription.
            return try I.write(newSub(session: session, errs: []))
        case .login(let cont):
            // todo take cont into account
            var path = "https://github.com/login/oauth/authorize?scope=user:email&client_id=\(Github.clientId)"
            if let c = cont {
                let baseURL = env["BASE_URL"]
                path.append("&redirect_uri=\(baseURL)" + Route.githubCallback("", origin: c.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!).path)
            }
            print(path)
            return I.redirect(path: path)
        case .logout:
            return withConnection { conn in
                guard let c = conn else { return .write("No database connection") }
                if let s = session {
                    tryOrPrint { try c.execute(s.user.deleteSession(s.sessionId)) }
                }
                return I.redirect(to: .home)
            }
        case .githubCallback(let code, let origin):
            return I.onComplete(promise:
                URLSession.shared.load(Github.getAccessToken(code)).map({ $0?.access_token })
            	, do: { token in
                guard let t = token else { return .write("No access") }
                return I.onComplete(promise: URLSession.shared.load(Github(t).profile), do: { str in
                    guard let p = str else { return .write("No profile") }
                    do {
                        return try withConnection { conn in
                            guard let c = conn else { return .write("No database connection") }
                            // todo ask for email if we don't get it
                            let uid: UUID
                            if let user = try c.execute(UserResult.select(githubId: p.id)) {
                                uid = user.id
                                print("Found existing user: \(user)")
                            } else {
                                let userData = UserData(email: p.email ?? "no email", githubUID: p.id, githubLogin: p.login, githubToken: t, avatarURL: p.avatar_url, name: p.name ?? "")
                                uid = try c.execute(userData.insert)
                                print("Created new user: \(userData)")
                            }
                            let sessionData: SessionData = SessionData(userId: uid)
                            let sid = try c.execute(sessionData.insert)
                            let destination: String
                            if let o = origin, o.hasPrefix("/") {
                                destination = o
                            } else {
                                destination = "/"
                            }
                            return I.redirect(path: destination, headers: ["Set-Cookie": "sessionid=\"\(sid.uuidString)\"; HttpOnly; Path=/"]) // TODO secure, TODO return to where user came from
                        }
                    } catch {
                        print("something else: \(error)", to: &standardError)
                        print("something else: \(error.localizedDescription)", to: &standardError)
                        return I.write("Error", status: .internalServerError)
                    }
                })
                
            })
        case .version:
            return .write(withConnection { conn -> String in
                let v = try? conn?.execute("SELECT version()") ?? nil
                return v.map { "\($0)" } ?? "no version"
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

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

runMigrations()
loadStaticData()

let s = MyServer(handle: { request in
    guard let route = Route(request) else { return nil }
    let sessionString = request.cookies.first { $0.0 == "sessionid" }?.1
    let sessionId = sessionString.flatMap { UUID(uuidString: $0) }
    return catchAndDisplayError { try route.interpret(sessionId: sessionId) }
}, resourcePaths: resourcePaths)
try s.listen()


