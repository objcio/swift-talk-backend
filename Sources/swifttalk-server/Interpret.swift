//
//  Interpret.swift
//  Bits
//
//  Created by Chris Eidhof on 24.08.18.
//

import Foundation
import PostgreSQL
import NIOHTTP1


struct NotLoggedInError: Error { }

struct Context {
    var path: String
    var route: Route
    var message: (String, FlashType)?
    var session: Session?
}

struct Session {
    var sessionId: UUID
    var user: Row<UserData>
    var masterTeamUser: Row<UserData>?
    
    var premiumAccess: Bool {
        return selfPremiumAccess || teamMemberPremiumAccess
    }
    
    var teamMemberPremiumAccess: Bool {
        return masterTeamUser?.data.premiumAccess == true
    }
    
    var selfPremiumAccess: Bool {
        return user.data.premiumAccess
    }
}


func requirePost<I: Interpreter>(csrf: CSRFToken, next: @escaping () throws -> I) throws -> I {
    return I.withPostBody(do: { body in
        guard body["csrf"] == csrf.stringValue else {
            throw RenderingError(privateMessage: "CSRF failure", publicMessage: "Something went wrong.")
        }
        return try next()
    })
}

extension ProfileFormData {
    init(_ data: UserData) {
        email = data.email
        name = data.name
    }
}

extension Interpreter {
    static func write(_ html: Node, status: HTTPResponseStatus = .ok) -> Self {
        return Self.write(html.htmlDocument(input: LayoutDependencies(hashedAssetName: { file in
            guard let remainder = file.drop(prefix: "/assets/") else { return file }
            let rep = assets.fileToHash[remainder]
            return rep.map { "/assets/" + $0 } ?? file
        })), status: status)
    }
}
 
extension Swift.Collection where Element == Episode {
    func withProgress(for userId: UUID?, connection: Lazy<Connection>) throws -> [EpisodeWithProgress] {
        guard let id = userId else { return map { EpisodeWithProgress(episode: $0, progress: nil) } }
        let progresses = try connection.get().execute(Row<PlayProgressData>.sortedDesc(for: id)).map { $0.data }
        return map { episode in
            // todo this is (n*m), we should use the fact that `progresses` is sorted!
            EpisodeWithProgress(episode: episode, progress: progresses.first { $0.episodeNumber == episode.number }?.progress)
        }
    }
}

extension Route {
    func interpret<I: Interpreter>(sessionId: UUID?, connection c: Lazy<Connection>) throws -> I {
        let session: Session?
        if self.loadSession, let sId = sessionId {
            let user = try c.get().execute(Row<UserData>.select(sessionId: sId))
            session = try user.map { u in
                let masterTeamuser = u.data.premiumAccess ? nil : try c.get().execute(u.masterTeamUser)
                return Session(sessionId: sId, user: u, masterTeamUser: masterTeamuser)
            }
        } else {
            session = nil
        }
        func requireSession() throws -> Session {
            return try session ?! NotLoggedInError()
        }
        
        let context = Context(path: path, route: self, message: nil, session: session)
        
        // Renders a form. If it's POST, we try to parse the result and call the `onPost` handler, otherwise (a GET) we render the form.
        func form<A>(_ f: Form<A>, initial: A, csrf: CSRFToken, validate: @escaping (A) -> [ValidationError], onPost: @escaping (A) throws -> I) -> I {
            return I.withPostBody(do: { body in
                guard let result = f.parse(csrf: csrf, body) else { throw RenderingError(privateMessage: "Couldn't parse form", publicMessage: "Something went wrong. Please try again.") }
                let errors = validate(result)
                if errors.isEmpty {
                	return try onPost(result)
                } else {
                    return .write(f.render(result, csrf, errors))
                }
            }, or: {
                return .write(f.render(initial, csrf, []))
            })
        }
        
        func teamMembersResponse(_ session: Session, _ data: TeamMemberFormData? = nil, csrf: CSRFToken, _ errors: [ValidationError] = []) throws -> I {
            let renderedForm = addTeamMemberForm().render(data ?? TeamMemberFormData(githubUsername: ""), csrf, errors)
            let members = try c.get().execute(session.user.teamMembers)
            return I.write(teamMembers(context: context, csrf: csrf, addForm: renderedForm, teamMembers: members))
        }
    
        func newSubscription(couponCode: String?, csrf: CSRFToken, errs: [String]) throws -> I {
            if let c = couponCode {
                return I.onSuccess(promise: recurly.coupon(code: c).promise, do: { coupon in
                    return try I.write(newSub(context: context, csrf: csrf, coupon: coupon, errs: errs))
                })
            } else {
                return try I.write(newSub(context: context, csrf: csrf, coupon: nil, errs: errs))
            }
        }

        switch self {
        case .error:
            return .write(errorView("Not found"), status: .notFound)
        case .collections:
            return I.write(index(Collection.all.filter { !$0.episodes(for: session?.user.data).isEmpty }, context: context))
        case .thankYou:
            let episodesWithProgress = try Episode.all.scoped(for: session?.user.data).withProgress(for: session?.user.id, connection: c)
            var cont = context
            cont.message = ("Thank you for supporting us.", .notice)
            return .write(renderHome(episodes: episodesWithProgress, context: cont))
        case .register(let couponCode):
            let s = try requireSession()
            return I.withPostBody(do: { body in
                guard let result = registerForm(context, couponCode: couponCode).parse(csrf: s.user.data.csrf, body) else {
                    throw RenderingError(privateMessage: "Failed to parse form data to create an account", publicMessage: "Something went wrong during account creation. Please try again.")
                }
                var u = s.user
                u.data.email = result.email
                u.data.name = result.name
                u.data.confirmedNameAndEmail = true
                let errors = u.data.validate()
                if errors.isEmpty {
                    try c.get().execute(u.update())
                    return I.redirect(to: Route.newSubscription(couponCode: couponCode))
                } else {
                    let result = registerForm(context, couponCode: couponCode).render(result, u.data.csrf, errors)
                    return I.write(result)
                }
            })
        case .createSubscription(let couponCode):
            let s = try requireSession()
            return I.withPostBody(csrf: s.user.data.csrf) { dict in
                guard let planId = dict["plan_id"], let token = dict["billing_info[token]"] else {
                    throw RenderingError(privateMessage: "Incorrect post data", publicMessage: "Something went wrong")
                }
                let plan = try Plan.all.first(where: { $0.plan_code == planId }) ?! RenderingError.init(privateMessage: "Illegal plan: \(planId)", publicMessage: "Couldn't find the plan you selected.")
                let cr = CreateSubscription.init(plan_code: plan.plan_code, currency: "USD", coupon_code: couponCode, account: .init(account_code: s.user.id, email: s.user.data.email, billing_info: .init(token_id: token)))
                return I.onSuccess(promise: recurly.createSubscription(cr).promise, message: "Something went wrong, please try again", do: { sub_ in
                    switch sub_ {
                    case .errors(let messages):
                        log(RecurlyErrors(messages))
                        if messages.contains(where: { $0.field == "subscription.account.email" && $0.symbol == "invalid_email" }) {
                            let response = registerForm(context, couponCode: couponCode).render(.init(s.user.data), s.user.data.csrf, [ValidationError("email", "Please provide a valid email address and try again.")])
                            return I.write(response)
                        }
                        return try newSubscription(couponCode: couponCode, csrf: s.user.data.csrf, errs: messages.map { $0.message })
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
            guard let coll = Collection.all.first(where: { $0.id == name }) else {
                return .write(errorView("No such collection"), status: .notFound)
            }
            let episodesWithProgress = try coll.episodes(for: session?.user.data).withProgress(for: session?.user.id, connection: c)
            return .write(coll.show(episodes: episodesWithProgress, context: context))
        case .newSubscription(let couponCode):
            let s = try requireSession()
            let u = s.user
            if !u.data.confirmedNameAndEmail {
                let resp = registerForm(context, couponCode: couponCode).render(.init(u.data), u.data.csrf, [])
                return I.write(resp)
            } else {
                return try newSubscription(couponCode: couponCode, csrf: u.data.csrf, errs: [])
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
            let loadToken = github.getAccessToken(code).promise.map({ $0?.access_token })
            return I.onComplete(promise: loadToken, do: { token in
                let t = try token ?! RenderingError(privateMessage: "No github access token", publicMessage: "Couldn't access your Github profile.")
                let loadProfile = Github(accessToken: t).profile.promise
                return I.onSuccess(promise: loadProfile, message: "Couldn't access your Github profile", do: { profile in
                    let uid: UUID
                    if let user = try c.get().execute(Row<UserData>.select(githubId: profile.id)) {
                        uid = user.id
                    } else {
                        let userData = UserData(email: profile.email ?? "", githubUID: profile.id, githubLogin: profile.login, githubToken: t, avatarURL: profile.avatar_url, name: profile.name ?? "")
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
        case let .episode(id, playPosition):
            guard let ep = Episode.all.findEpisode(with: id, scopedFor: session?.user.data) else {
                return .write(errorView("No such episode"), status: .notFound)
            }
            let downloads = try (session?.user.downloads).map { try c.get().execute($0) } ?? []
            let status = session?.user.data.downloadStatus(for: ep, downloads: downloads) ?? .notSubscribed
            let allEpisodes = try Episode.all.scoped(for: session?.user.data).withProgress(for: session?.user.id, connection: c)
            let featuredEpisodes = Array(allEpisodes.filter { $0.episode != ep }.prefix(8))
            let position = playPosition ?? allEpisodes.first { $0.episode == ep }?.progress
            return .write(ep.show(playPosition: position, downloadStatus: status, otherEpisodes: featuredEpisodes, context: context))
        case .episodes:
            let episodesWithProgress = try Episode.all.scoped(for: session?.user.data).withProgress(for: session?.user.id, connection: c)
            return I.write(index(episodesWithProgress, context: context))
        case .home:
            let episodesWithProgress = try Episode.all.scoped(for: session?.user.data).withProgress(for: session?.user.id, connection: c)
            return .write(renderHome(episodes: episodesWithProgress, context: context))
        case .sitemap:
            return .write(Route.siteMap)
        case .promoCode(let str):
            return I.onSuccess(promise: recurly.coupon(code: str).promise, message: "Can't find that coupon.", do: { coupon in
                guard coupon.state == "redeemable" else {
                    throw RenderingError(privateMessage: "not redeemable: \(str)", publicMessage: "This coupon is not redeemable anymore.")
                }
                return try I.write(Plan.all.subscribe(context: context, coupon: coupon))
            })
        case .download(let id):
            let s = try requireSession()
            guard let ep = Episode.all.findEpisode(with: id, scopedFor: session?.user.data) else {
                return .write(errorView("No such episode"), status: .notFound)
            }
            return .onComplete(promise: vimeo.downloadURL(for: ep.vimeoId).promise) { downloadURL in
                guard let result = downloadURL, let url = result else { return .redirect(to: .episode(ep.id, playPosition: nil)) }
                let downloads = try c.get().execute(s.user.downloads)
                switch s.user.data.downloadStatus(for: ep, downloads: downloads) {
                case .reDownload:
                    return .redirect(path: url.absoluteString)
                case .canDownload:
                    try c.get().execute(DownloadData(user: s.user.id, episode: ep.number).insert)
                    return .redirect(path: url.absoluteString)
                default:
                    return .redirect(to: .episode(ep.id, playPosition: nil)) // just redirect back to episode page if somebody tries this without download credits
                }
            }
        case let .staticFile(path: p):
            let name = p.map { $0.removingPercentEncoding ?? "" }.joined(separator: "/")
            if let n = assets.hashToFile[name] {
                return I.writeFile(path: n, maxAge: 31536000)
            } else {
            	return .writeFile(path: name)
            }
        case .accountProfile:
            let sess = try requireSession()
            var u = sess.user
            let data = ProfileFormData(email: u.data.email, name: u.data.name)
            let f = accountForm(context: context)
            return form(f, initial: data, csrf: u.data.csrf, validate: { _ in [] }, onPost: { result in
                // todo: this is almost the same as the new account logic... can we abstract this?
                u.data.email = result.email
                u.data.name = result.name
                u.data.confirmedNameAndEmail = true
                let errors = u.data.validate()
                if errors.isEmpty {
                    try c.get().execute(u.update())
                    return I.redirect(to: .accountProfile)
                } else {
                    return I.write(f.render(result, u.data.csrf, errors))
                }
            })
        case .accountBilling:
            let sess = try requireSession()
            var user = sess.user
            func renderBilling(recurlyToken: String) -> I {
                let invoicesAndPDFs = sess.user.invoices.promise.map { invoices in
                    return invoices?.map { invoice in
                        (invoice, recurly.pdfURL(invoice: invoice, hostedLoginToken: recurlyToken))
                    }
                }
                let redemptions = sess.user.redemptions.promise.map { r in
                    r?.filter { $0.state == "active" }
                }
                let promise = zip(sess.user.currentSubscription.promise, invoicesAndPDFs, redemptions, sess.user.billingInfo.promise, recurly.coupons().promise).map(zip)
                return I.onSuccess(promise: promise, do: { p in
                    let (sub, invoicesAndPDFs, redemptions, billingInfo, coupons) = p
                    func cont(subAndAddOn: (Subscription, Plan.AddOn)?) throws -> I {
                        let redemptionsWithCoupon = try redemptions.map { (r) -> (Redemption, Coupon) in
                            guard let c = coupons.first(where: { $0.coupon_code == r.coupon_code }) else {
                                throw RenderingError(privateMessage: "No coupon for \(r)!", publicMessage: "Something went wrong.")
                            }
                            return (r,c)
                        }
                        let result = billing(context: context, user: sess.user, subscription: subAndAddOn, invoices: invoicesAndPDFs, billingInfo: billingInfo, redemptions: redemptionsWithCoupon)
                        return I.write(result)
                    }
                    if let s = sub, let p = Plan.all.first(where: { $0.plan_code == s.plan.plan_code }) {
                        return I.onSuccess(promise: p.teamMemberAddOn.promise, do: { addOn in
                            try cont(subAndAddOn: (s, addOn))
                    	})
                    } else {
                        return try cont(subAndAddOn: nil)
                    }
                })
            }
            guard let t = sess.user.data.recurlyHostedLoginToken else {
                return I.onSuccess(promise: sess.user.account.promise, do: { acc in
                    user.data.recurlyHostedLoginToken = acc.hosted_login_token
                    try c.get().execute(user.update())
                    return renderBilling(recurlyToken: acc.hosted_login_token)
                }, or: {
                    if sess.teamMemberPremiumAccess {
                        return I.write(teamMemberBilling(context: context))
                    } else {
                        return I.write(unsubscribedBilling(context: context))
                    }
                })
            }
            return renderBilling(recurlyToken: t)
        case .cancelSubscription:
            let sess = try requireSession()
            let user = sess.user
            return try requirePost(csrf: user.data.csrf) {
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
            }
        case .upgradeSubscription:
            let sess = try requireSession()
            return try requirePost(csrf: sess.user.data.csrf) {
                return I.onSuccess(promise: sess.user.currentSubscription.promise.map(flatten), do: { (sub: Subscription) throws -> I in
                    guard let u = sub.upgrade else { throw RenderingError(privateMessage: "no upgrade available \(sub)", publicMessage: "There's no upgrade available.")}
                    let teamMembers = try c.get().execute(sess.user.teamMembers)
                    return I.onSuccess(promise: recurly.updateSubscription(sub, plan_code: u.plan.plan_code, numberOfTeamMembers: teamMembers.count).promise, do: { (result: Subscription) throws -> I in
                        return I.redirect(to: .accountBilling)
                    })
                })
            }
        case .reactivateSubscription:
            let sess = try requireSession()
            let user = sess.user
            return try requirePost(csrf: user.data.csrf) {
                return I.onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                    guard sub.state == .canceled else {
                        throw RenderingError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find a cancelled subscription.")
                    }
                    return I.onSuccess(promise: recurly.reactivate(sub).promise) { result in
                        switch result {
                        case .success: return I.redirect(to: .thankYou)
                        case .errors(let errs): throw RecurlyErrors(errs)
                        }
                    }

                }
            }
        case .accountUpdatePayment:
            let sess = try requireSession()
            func renderForm(errs: [RecurlyError]) -> I {
                return I.onSuccess(promise: sess.user.billingInfo.promise, do: { billingInfo in
                    let view = updatePaymentView(context: context, data: PaymentViewData(billingInfo, action: Route.accountUpdatePayment.path, csrf: sess.user.data.csrf, publicKey: env.recurlyPublicKey, buttonText: "Update", paymentErrors: errs.map { $0.message }))
                    return I.write(view)
                })
            }
            return I.withPostBody(csrf: sess.user.data.csrf, do: { body in
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
            let csrf = sess.user.data.csrf
            return I.withPostBody(do: { params in
                guard let formData = addTeamMemberForm().parse(csrf: csrf, params), sess.selfPremiumAccess else { return try teamMembersResponse(sess, csrf: csrf) }
                let promise = github.profile(username: formData.githubUsername).promise
                return I.onComplete(promise: promise) { profile in
                    guard let p = profile else {
                        return try teamMembersResponse(sess, formData, csrf: csrf, [(field: "github_username", message: "No user with this username exists on GitHub")])
                    }
                    let newUserData = UserData(email: p.email ?? "", githubUID: p.id, githubLogin: p.login, avatarURL: p.avatar_url, name: p.name ?? "")
                    let newUserid = try c.get().execute(newUserData.findOrInsert(uniqueKey: "github_uid", value: p.id))
                    let teamMemberData = TeamMemberData(userId: sess.user.id, teamMemberId: newUserid)
                    guard let _ = try? c.get().execute(teamMemberData.insert) else {
                        return try teamMembersResponse(sess, formData, csrf: csrf, [(field: "github_username", message: "Team member already exists")])
                    }
                    let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: Date().addingTimeInterval(5*60))
                    try c.get().execute(task)
                    return try teamMembersResponse(sess, csrf: csrf)
                }
            }, or: {
                return try teamMembersResponse(sess, csrf: csrf)
            })
        
        case .accountDeleteTeamMember(let id):
            let sess = try requireSession()
            let csrf = sess.user.data.csrf
            return try requirePost(csrf: csrf) {
                try c.get().execute(sess.user.deleteTeamMember(id))
                let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: Date().addingTimeInterval(5*60))
                try c.get().execute(task)
                return try teamMembersResponse(sess, csrf: csrf)
            }
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
                    row.data.canceled = s.canceled
                    guard let _ = try? c.get().execute(row.update()) else {
                        return log(error: "Failed to update user \(id) in response to Recurly webhook")
                    }
                }
                return I.write("", status: .ok)
            }
        case .githubWebhook:
            // This could be done more fine grained, but this works just fine for now
            refreshStaticData()
            return I.write("", status: .ok)
        case .rssFeed:
            return I.write(xml: Episode.all.released.rssView, status: .ok)
        case let .episodesJSON(showUnreleased: key):
            let secret = "2CF2557A-4AD9-4E39-99CB-22D61BEC04F6" // TODO: this should be an ENV variable
            let json = episodesJSONView(showUnreleased: key == secret)
            return I.write(json: json)
        case let .collectionsJSON(showUnreleased: key):
            let secret = "2CF2557A-4AD9-4E39-99CB-22D61BEC04F6"
            let json = collectionsJSONView(showUnreleased: key == secret)
            return I.write(json: json)
        case .gift:
        	return I.write("gift landing page")
        case .newGift:
            // todo case where user is logged in.
            return form(giftForm(context: context), initial: GiftStep1.empty, csrf: sharedCSRF, validate: { $0.validate() }, onPost: { gift in
                dump(gift) // todo insert into DB
                return I.redirect(to: Route.payGift(UUID()))
            })
        case .payGift(let id):
            let f = payGiftForm(context: context, route: .payGift(id))
            return form(f, initial: RecurlyToken(value: ""), csrf: sharedCSRF, validate: { _ in [] }, onPost: { (token: RecurlyToken) throws in
                dump(token)
                return I.write("todo")
            })
        case let .playProgress(episodeId):
            guard let s = try? requireSession() else { return I.write("", status: .ok)}
            return I.withPostBody(csrf: s.user.data.csrf) { body in
                if let progress = body["progress"].flatMap(Int.init), let ep = Episode.all.findEpisode(with: episodeId, scopedFor: s.user.data) {
                    let data = PlayProgressData.init(userId: s.user.id, episodeNumber: ep.number, progress: progress, furthestWatched: progress)
                    try c.get().execute(data.insertOrUpdate(uniqueKey: "user_id, episode_number"))
                }
                return I.write("", status: .ok)
            }
        }
    }
}

let sharedCSRF = CSRFToken(UUID(uuidString: "F5F6C2AE-85CB-4989-B0BF-F471CC92E3FF")!)
