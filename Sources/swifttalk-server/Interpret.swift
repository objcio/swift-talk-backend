//
//  Interpret.swift
//  Bits
//
//  Created by Chris Eidhof on 24.08.18.
//

import Foundation
import PostgreSQL

extension Interpreter {
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError { try cont(value) }
        })
    }
    
    static func onSuccess<A>(promise: Promise<A?>, file: StaticString = #file, line: UInt = #line, message: String = "Something went wrong.", do cont: @escaping (A) throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError {
                guard let v = value else {
                    throw RenderingError(privateMessage: "Expected non-nil value, but got nil (\(file):\(line)).", publicMessage: message)
                }
                return try cont(v)
            }
        })
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) throws -> Self) -> Self {
        return .withPostBody { dict in
            return catchAndDisplayError { try cont(dict) }
        }
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) throws -> Self, or: @escaping () throws -> Self) -> Self {
        return .withPostData { data in
            return catchAndDisplayError {
                // TODO instead of checking whether data is empty, we should check whether it was a post?
                if !data.isEmpty, let r = String(data: data, encoding: .utf8)?.parseAsQueryPart {
                    return try cont(r)
                } else {
                    return try or()
                }
            }
        }
    }
}

struct NotLoggedInError: Error { }

struct Context {
    var path: String
    var route: Route
    var session: Session?
}

// TODO: we should implement this!
func requirePost() throws -> () {
}

extension ProfileFormData {
    init(_ data: UserData) {
        email = data.email
        name = data.name
    }
}

extension Route {
    func interpret<I: Interpreter>(sessionId: UUID?, connection c: Lazy<Connection>) throws -> I {
        let session: Session?
        if self.loadSession, let sId = sessionId {
            let user = try c.get().execute(Row<UserData>.select(sessionId: sId))
            session = try user.map { u in
                let masterTeamuser = u.data.premiumAccess ? nil : try c.get().execute(u.masterTeamUser)
                return Session(sessionId: sId, user: u, masterTeamUser: masterTeamuser, csrfToken: "TODO")
            }
        } else {
            session = nil
        }
        func requireSession() throws -> Session {
            return try session ?! NotLoggedInError()
        }
        
        let context = Context(path: path, route: self, session: session)
        
        // Renders a form. If it's POST, we try to parse the result and call the `onPost` handler, otherwise (a GET) we render the form.
        func form<A>(_ f: Form<A>, initial: A, onPost: @escaping (A) throws -> I) -> I {
            return I.withPostBody(do: { body in
                guard let result = f.parse(body) else { throw RenderingError(privateMessage: "Couldn't parse form", publicMessage: "Something went wrong. Please try again.") }
                return try onPost(result)
            }, or: {
                return .write(f.render(initial, []))
            })
        }
        
        func teamMembersResponse(_ session: Session, _ data: TeamMemberFormData? = nil, _ errors: [ValidationError] = []) throws -> I {
            let renderedForm = addTeamMemberForm().render(data ?? TeamMemberFormData(githubUsername: ""), errors)
            let members = try c.get().execute(session.user.teamMembers)
            return I.write(teamMembers(context: context, addForm: renderedForm, teamMembers: members))
        }
        
        func processTasks(_ tasks: [Row<TaskData>]) {
            if let task = tasks.first {
                try? task.process(c) { _ in
                    processTasks(Array(tasks.dropFirst()))
                }
            }
        }


        switch self {
        case .books, .issues, .error:
            return .notFound()
        case .collections:
            return I.write(index(Collection.all.filter { !$0.episodes(for: session?.user.data).isEmpty }, context: context))
        case .thankYou:
            return .write("TODO thanks")
        case .register:
            let s = try requireSession()
            return I.withPostBody(do: { body in
                guard let result = registerForm(context).parse(body) else {
                    throw RenderingError(privateMessage: "Failed to parse form data to create an account", publicMessage: "Something went wrong during account creation. Please try again.")
                }
                var u = s.user
                u.data.email = result.email
                u.data.name = result.name
                u.data.confirmedNameAndEmail = true
                let errors = u.data.validate()
                if errors.isEmpty {
                    try c.get().execute(u.update())
                    return I.redirect(to: .newSubscription)
                } else {
                    return I.write(registerForm(context).render(result, errors))
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
                return I.onSuccess(promise: URLSession.shared.load(req), message: "Something went wrong, please try again", do: { sub_ in
                    switch sub_ {
                    case .errors(let messages):
                        if messages.contains(where: { $0.field == "subscription.account.email" && $0.symbol == "invalid_email" }) {
                            let response = registerForm(context).render(.init(s.user.data), [ValidationError("email", "Please provide a valid email address.")])
                            return I.write(response)
                        }
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
                return I.notFound("No such collection")
            }
            return .write(c.show(context: context))
        case .newSubscription:
            let s = try requireSession()
            let u = s.user
            if !u.data.confirmedNameAndEmail {
                return I.write(registerForm(context).render(.init(u.data), []))
            } else {
                return try I.write(newSub(context: context, errs: []))
            }
        case .login(let cont):
            var path = "https://github.com/login/oauth/authorize?scope=user:email&client_id=\(github.clientId)"
            if let c = cont {
                let encoded = env.baseURL.absoluteString + Route.githubCallback("", origin: c).path
                path.append("&redirect_uri=" + encoded.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
            }
            return I.redirect(path: path)
        case .logout:
            let s = try requireSession()
            try c.get().execute(s.user.deleteSession(s.sessionId))
            return I.redirect(to: .home)
        case .githubCallback(let code, let origin):
            let loadToken = URLSession.shared.load(github.getAccessToken(code)).map({ $0?.access_token })
            return I.onComplete(promise: loadToken, do: { token in
                let t = try token ?! RenderingError(privateMessage: "No github access token", publicMessage: "Couldn't access your Github profile.")
                let loadProfile = URLSession.shared.load(Github(accessToken: t).profile)
                return I.onSuccess(promise: loadProfile, message: "Couldn't access your Github profile", do: { profile in
                    let uid: UUID
                    if let user = try c.get().execute(Row<UserData>.select(githubId: profile.id)) {
                        uid = user.id
                    } else {
                        let userData = UserData(email: profile.email ?? "no email", githubUID: profile.id, githubLogin: profile.login, githubToken: t, avatarURL: profile.avatar_url, name: profile.name ?? "")
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
            return .write(renderHome(context: context))
        case .sitemap:
            return .write(Route.siteMap)
        case .download(let id):
            let s = try requireSession()
            guard let ep = Episode.scoped(for: session?.user.data).first(where: { $0.id == id }) else {
                return .notFound("No such episode")
            }
            return .onComplete(promise: URLSession.shared.load(vimeo.downloadURL(for: ep.vimeo_id))) { downloadURL in
                guard let result = downloadURL, let url = result else { return .redirect(to: .episode(ep.id)) }
                let downloads = try c.get().execute(s.user.downloads)
                switch s.user.downloadStatus(for: ep, downloads: downloads) {
                case .reDownload:
                    return .redirect(path: url.absoluteString)
                case .canDownload:
                    try c.get().execute(DownloadData(user: s.user.id, episode: ep.number).insert)
                    return .redirect(path: url.absoluteString)
                default:
                    return .redirect(to: .episode(ep.id)) // just redirect back to episode page if somebody tries this without download credits
                }
            }
        case let .staticFile(path: p):
            let name = p.map { $0.removingPercentEncoding ?? "" }.joined(separator: "/")
            return .writeFile(path: name)
        case .accountProfile:
            let sess = try requireSession()
            var u = sess.user
            let data = ProfileFormData(email: u.data.email, name: u.data.name)
            let f = accountForm(context: context)
            return form(f, initial: data, onPost: { result in
                // todo: this is almost the same as the new account logic... can we abstract this?
                u.data.email = result.email
                u.data.name = result.name
                u.data.confirmedNameAndEmail = true
                let errors = u.data.validate()
                if errors.isEmpty {
                    try c.get().execute(u.update())
                    return I.redirect(to: .accountProfile)
                } else {
                    return I.write(f.render(result, errors))
                }
            })
//                return I.onComplete(promise: sess.user.monthsOfActiveSubscription, do: { num in
//                    let d = try c.get().execute(sess.user.downloads).count
//                    return .write("Number of months of subscription: \(num ?? 0), downloads: \(d)")
//                })
        case .accountBilling:
            let sess = try requireSession()
            var user = sess.user
            func renderBilling(recurlyToken: String) -> I {
                return I.onSuccess(promise: sess.user.currentSubscription.promise, do: { sub in
                    return I.onSuccess(promise: sess.user.invoices.promise, do: { invoices in
                        let invoicesAndPDFs = invoices.map { invoice in
                            (invoice, recurly.pdfURL(invoice: invoice, hostedLoginToken: recurlyToken))
                        }
                        return I.onSuccess(promise: sess.user.billingInfo.promise, do: { billingInfo in
                            return I.write(billing(context: context, user: sess.user, subscription: sub, invoices: invoicesAndPDFs, billingInfo: billingInfo))
                        })
                    })
                })
            }
            guard let t = sess.user.data.recurlyHostedLoginToken else {
                return I.onSuccess(promise: sess.user.account.promise) { acc in
                    user.data.recurlyHostedLoginToken = acc.hosted_login_token
                    try c.get().execute(user.update())
                    return renderBilling(recurlyToken: acc.hosted_login_token)
                }
            }
            return renderBilling(recurlyToken: t)
        case .cancelSubscription:
            try requirePost()
            let sess = try requireSession()
            let user = sess.user
            return I.onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                guard sub.state == .active else {
                    throw RenderingError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find an active subscription.")
                }
                return I.onSuccess(promise: recurly.cancel(sub).promise) { result in
                    switch result {
                    case .success: return I.redirect(to: .accountBilling)
                    case .errors(let errs): throw RecurlyErrors(errs)
                    }
                }
                
            }
        case .upgradeSubscription:
            try requirePost()
            let sess = try requireSession()
            return I.onSuccess(promise: sess.user.currentSubscription.promise.map(flatten), do: { (sub: Subscription) throws -> I in
                guard let u = sub.upgrade else { throw RenderingError(privateMessage: "no upgrade available \(sub)", publicMessage: "There's no upgrade available.")}
                let teamMembers = try c.get().execute(sess.user.teamMembers)
                return I.onSuccess(promise: recurly.updateSubscription(sub, plan_code: u.plan.plan_code, numberOfTeamMembers: teamMembers.count).promise, do: { (result: Subscription) throws -> I in
                    return I.redirect(to: .accountBilling)
                })
            })
        case .reactivateSubscription:
            try requirePost()
            let sess = try requireSession()
            let user = sess.user
            return I.onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                guard sub.state == .canceled else {
                    throw RenderingError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find a cancelled subscription.")
                }
                return I.onSuccess(promise: recurly.reactivate(sub).promise) { result in
                    switch result {
                    case .success: return I.redirect(to: .accountBilling)
                    case .errors(let errs): throw RecurlyErrors(errs)
                    }
                }
                
            }
        case .accountUpdatePayment:
            let sess = try requireSession()
            func renderForm(errs: [RecurlyError]) -> I {
                return I.onSuccess(promise: sess.user.billingInfo.promise, do: { billingInfo in
                    let view = updatePaymentView(context: context, data: PaymentViewData(billingInfo, action: Route.accountUpdatePayment.path, publicKey: env.recurlyPublicKey, buttonText: "Update", paymentErrors: errs.map { $0.message }))
                    return I.write(view)
                })
            }
            return I.withPostBody(do: { body in
                guard let token = body["billing_info[token]"] else {
                    throw RenderingError(privateMessage: "No billing_info[token]", publicMessage: "Something went wrong, please try again.")
                }
                return I.onSuccess(promise: sess.user.updateBillingInfo(token: token).promise, do: { (response: RecurlyResult<BillingInfo>) -> I in
                    switch response {
                    case .success: return I.redirect(to: .accountUpdatePayment) // todo show message?
                    case .errors(let errs): return renderForm(errs: errs)
                    }
                })
            }, or: {
                renderForm(errs: [])
            })
            
        case .accountTeamMembers:
            let sess = try requireSession()
            return I.withPostBody(do: { params in
                guard let formData = addTeamMemberForm().parse(params) else { return try teamMembersResponse(sess) }
                let promise = URLSession.shared.load(github.profile(username: formData.githubUsername))
                return I.onComplete(promise: promise) { profile in
                    guard let p = profile else {
                        return try teamMembersResponse(sess, formData, [(field: "github_username", message: "No user with this username exists on GitHub")])
                    }
                    let newUserData = UserData(email: p.email ?? "", githubUID: p.id, githubLogin: p.login, avatarURL: p.avatar_url, name: p.name ?? "")
                    let newUserid = try c.get().execute(newUserData.findOrInsert(uniqueKey: "github_uid", value: p.id))
                    let teamMemberData = TeamMemberData(userId: sess.user.id, teamMemberId: newUserid)
                    guard let _ = try? c.get().execute(teamMemberData.insert) else {
                        return try teamMembersResponse(sess, formData, [(field: "github_username", message: "Team member already exists")])
                    }
                    let task = try Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: Date().addingTimeInterval(5*60))
                    try c.get().execute(task)
                    return try teamMembersResponse(sess)
                }
            }, or: {
                return try teamMembersResponse(sess)
            })
        
        case .accountDeleteTeamMember(let id):
            try requirePost()
            let sess = try requireSession()
            try c.get().execute(sess.user.deleteTeamMember(id))
            let task = try Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: Date().addingTimeInterval(5*60))
            try c.get().execute(task)
            return try teamMembersResponse(sess)
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
        case .scheduledTask:
            let tasks = try c.get().execute(Row<TaskData>.dueTasks)
            processTasks(tasks)
            return I.write("", status: .ok)
        }
    }
}
