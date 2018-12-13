//
//  Interpret.swift
//  Bits
//
//  Created by Chris Eidhof on 24.08.18.
//

import Foundation
import PostgreSQL
import NIOHTTP1


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
    var gifter: Row<UserData>?
    
    var premiumAccess: Bool {
        return selfPremiumAccess || teamMemberPremiumAccess || gifterPremiumAccess
    }
    
    var activeSubscription: Bool {
        return (selfPremiumAccess && !user.data.canceled) ||
            (gifterPremiumAccess && gifter?.data.canceled == false) ||
            (teamMemberPremiumAccess && masterTeamUser?.data.canceled == false)
    }
    
    var teamMemberPremiumAccess: Bool {
        return masterTeamUser?.data.premiumAccess == true
    }
    
    var gifterPremiumAccess: Bool {
        return gifter?.data.premiumAccess == true
    }
    
    var selfPremiumAccess: Bool {
        return user.data.premiumAccess
    }
}


func requirePost<I: SwiftTalkInterpreter>(csrf: CSRFToken, next: @escaping () throws -> I) throws -> I {
    return I.withPostBody(do: { body in
        guard body["csrf"] == csrf.stringValue else {
            throw ServerError(privateMessage: "CSRF failure", publicMessage: "Something went wrong.")
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

extension SwiftTalkInterpreter {}
 
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

// Renders a form. If it's POST, we try to parse the result and call the `onPost` handler, otherwise (a GET) we render the form.
func form<A,B,I: SwiftTalkInterpreter>(_ f: Form<A>, initial: A, csrf: CSRFToken, convert: @escaping (A) -> Either<B, [ValidationError]>, validate: @escaping (B) -> [ValidationError], onPost: @escaping (B) throws -> I) -> I {
    return I.withPostBody(do: { body in
        guard let result = f.parse(csrf: csrf, body) else { throw ServerError(privateMessage: "Couldn't parse form", publicMessage: "Something went wrong. Please try again.") }
        switch convert(result) {
        case let .left(value):
            let errors = validate(value)
            if errors.isEmpty {
                return try onPost(value)
            } else {
                return .write(f.render(result, csrf, errors))
            }
            
        case let .right(errs):
            return .write(f.render(result, csrf, errs))
        }
        
    }, or: {
        return .write(f.render(initial, csrf, []))
    })
    
}

func form<A, I: SwiftTalkInterpreter>(_ f: Form<A>, initial: A, csrf: CSRFToken, validate: @escaping (A) -> [ValidationError], onPost: @escaping (A) throws -> I) -> I {
    return form(f, initial: initial, csrf: csrf, convert: { .left($0) }, validate: validate, onPost: onPost)
}

extension Route {
    func interpret<I: SwiftTalkInterpreter>(sessionId: UUID?, connection c: Lazy<Connection>) throws -> I {
        let session: Session?
        if self.loadSession, let sId = sessionId {
            let user = try c.get().execute(Row<UserData>.select(sessionId: sId))
            session = try user.map { u in
                if u.data.premiumAccess {
                    return Session(sessionId: sId, user: u, masterTeamUser: nil, gifter: nil)
                } else {
                    let masterTeamUser: Row<UserData>? = try c.get().execute(u.masterTeamUser)
                    let gifter: Row<UserData>? = try c.get().execute(u.gifter)
                    return Session(sessionId: sId, user: u, masterTeamUser: masterTeamUser, gifter: gifter)
                }
            }
        } else {
            session = nil
        }
        func requireSession() throws -> Session {
            return try session ?! AuthorizationError()
        }
        
        let context = Context(path: path, route: self, message: nil, session: session)
        switch self {
        case .error:
            return .write(errorView("Not found"), status: .notFound)
        case .collections:
            return I.write(index(Collection.all.filter { !$0.episodes(for: session?.user.data).isEmpty }, context: context))
        case .subscription(let s):
            return try s.interpret(sesssion: requireSession(), context: context, connection: c)
        case .account(let action):
            return try action.interpret(sesssion: requireSession(), context: context, connection: c)
        case .gift(let g):
            return try g.interpret(session: session, context: context, connection: c)
        case .subscribe:
            return try I.write(Plan.all.subscribe(context: context))
        case .collection(let name):
            guard let coll = Collection.all.first(where: { $0.id == name }) else {
                return .write(errorView("No such collection"), status: .notFound)
            }
            let episodesWithProgress = try coll.episodes(for: session?.user.data).withProgress(for: session?.user.id, connection: c)
            return .write(coll.show(episodes: episodesWithProgress, context: context))
        case .login(let cont):
            var path = "https://github.com/login/oauth/authorize?scope=user:email&client_id=\(github.clientId)"
            if let c = cont {
                let encoded = env.baseURL.absoluteString + Route.githubCallback(code: nil, origin: c).path
                path.append("&redirect_uri=" + encoded.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
            }
            return I.redirect(path: path)
        case .githubCallback(let optionalCode, let origin):
            guard let code = optionalCode else {
                throw ServerError(privateMessage: "No auth code", publicMessage: "Something went wrong, please try again.")
            }
            let loadToken = github.getAccessToken(code).promise.map({ $0?.access_token })
            return I.onComplete(promise: loadToken, do: { token in
                let t = try token ?! ServerError(privateMessage: "No github access token", publicMessage: "Couldn't access your Github profile.")
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
                    throw ServerError(privateMessage: "not redeemable: \(str)", publicMessage: "This coupon is not redeemable anymore.")
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
                    row.data.downloadCredits = Int(s.downloadCredits)
                    row.data.canceled = s.canceled
                    tryOrLog("Failed to update user \(id) in response to Recurly webhook") { try c.get().execute(row.update()) }
                    
                    func update(credits: Int, for users: [Row<UserData>]) {
                        for user in users {
                            var u = user
                            u.data.downloadCredits = row.data.downloadCredits
                            tryOrLog("Failed to update download credits for associated user \(u.id)") { try c.get().execute(u.update()) }
                        }
                    }
                    if let teamMembers = tryOrLog("Failed to get team members for \(row.id)", { try c.get().execute(row.teamMembers) }) {
                        update(credits: row.data.downloadCredits, for: teamMembers)
                    }
                    if let giftees = tryOrLog("Failed to get gifees for \(row.id)", { try c.get().execute(row.giftees) }) {
                        update(credits: row.data.downloadCredits, for: giftees)
                    }
                }
                
                return catchAndDisplayError {
                    if let s = webhook.subscription, s.plan.plan_code.hasPrefix("gift") {
                        if var gift = flatten(try? c.get().execute(Row<Gift>.select(subscriptionId: s.uuid))) {
                            log(info: "gift update \(s) \(gift)")
                            if s.state == "future", let a = s.activated_at {
                                if gift.data.sendAt != a {
                                    gift.data.sendAt = a
                                    try c.get().execute(gift.update())
                                }
                            } else if s.state == "active" {
                                if !gift.data.activated {
                                    let plan = Plan.gifts.first { $0.plan_code == s.plan.plan_code }
                                    let duration = plan?.prettyDuration ?? "unknown"
                                    let email = sendgrid.send(to: gift.data.gifteeEmail, name: gift.data.gifteeName, subject: "We have a gift for you...", text: gift.gifteeEmailText(duration: duration))
                                    log(info: "Sending gift email to \(gift.data.gifteeEmail)")
                                    URLSession.shared.load(email) { result in
                                        log(error: "Can't send email for gift \(gift)")
                                    }
                                    gift.data.activated = true
                                    try c.get().execute(gift.update())
                                }
                            }
                            return I.write("", status: .ok)
                        } else {
                            log(error: "Got a recurly webhook but can't find gift \(s)")
                            return I.write("", status: .internalServerError)
                        }
                    }
                    return I.write("", status: .ok)
                }
            }
        case .githubWebhook:
            // This could be done more fine grained, but this works just fine for now
            refreshStaticData()
            return I.write("", status: .ok)
        case .rssFeed:
            return I.write(xml: Episode.all.released.rssView, status: .ok)
        case .episodesJSON:
            return I.write(json: episodesJSONView())
        case .collectionsJSON:
            return I.write(json: collectionsJSONView())
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

extension Route.Subscription {
    func interpret<I: SwiftTalkInterpreter>(sesssion sess: Session, context: Context, connection c: Lazy<Connection>) throws -> I {
        let user = sess.user
        func newSubscription(couponCode: String?, errs: [String]) throws -> I {
            if let c = couponCode {
                return I.onSuccess(promise: recurly.coupon(code: c).promise, do: { coupon in
                    return try I.write(newSub(context: context, csrf: sess.user.data.csrf, coupon: coupon, errs: errs))
                })
            } else {
                return try I.write(newSub(context: context, csrf: sess.user.data.csrf, coupon: nil, errs: errs))
            }
        }

        switch self {
        case .create(let couponCode):
            return I.withPostBody(csrf: sess.user.data.csrf) { dict in
                guard let planId = dict["plan_id"], let token = dict["billing_info[token]"] else {
                    throw ServerError(privateMessage: "Incorrect post data", publicMessage: "Something went wrong")
                }
                let plan = try Plan.all.first(where: { $0.plan_code == planId }) ?! ServerError.init(privateMessage: "Illegal plan: \(planId)", publicMessage: "Couldn't find the plan you selected.")
                let cr = CreateSubscription.init(plan_code: plan.plan_code, currency: "USD", coupon_code: couponCode, starts_at: nil, account: .init(account_code: user.id, email: user.data.email, billing_info: .init(token_id: token)))
                return I.onSuccess(promise: recurly.createSubscription(cr).promise, message: "Something went wrong, please try again", do: { sub_ in
                    switch sub_ {
                    case .errors(let messages):
                        log(RecurlyErrors(messages))
                        if messages.contains(where: { $0.field == "subscription.account.email" && $0.symbol == "invalid_email" }) {
                            let response = registerForm(context, couponCode: couponCode).render(.init(user.data), user.data.csrf, [ValidationError("email", "Please provide a valid email address and try again.")])
                            return I.write(response)
                        }
                        return try newSubscription(couponCode: couponCode, errs: messages.map { $0.message })
                    case .success(let sub):
                        try c.get().execute(user.changeSubscriptionStatus(sub.state == .active))
                        return I.redirect(to: .account(.thankYou))
                    }
                })
            }
        case .new(let couponCode):
            if !user.data.confirmedNameAndEmail {
                let resp = registerForm(context, couponCode: couponCode).render(.init(user.data), user.data.csrf, [])
                return I.write(resp)
            } else {
                try c.get().execute(Task.unfinishedSubscriptionReminder(userId: user.id).schedule(weeks: 1))
                return try newSubscription(couponCode: couponCode, errs: [])
            }
        case .cancel:
            return try requirePost(csrf: user.data.csrf) {
                return I.onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                    guard sub.state == .active else {
                        throw ServerError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find an active subscription.")
                    }
                    return I.onSuccess(promise: recurly.cancel(sub).promise) { result in
                        switch result {
                        case .success: return I.redirect(to: .account(.billing))
                        case .errors(let errs): throw RecurlyErrors(errs)
                        }
                    }
                    
                }
            }
        case .upgrade:
            return try requirePost(csrf: sess.user.data.csrf) {
                return I.onSuccess(promise: sess.user.currentSubscription.promise.map(flatten), do: { sub throws -> I in
                    guard let u = sub.upgrade else { throw ServerError(privateMessage: "no upgrade available \(sub)", publicMessage: "There's no upgrade available.")}
                    let teamMembers = try c.get().execute(sess.user.teamMembers)
                    return I.onSuccess(promise: recurly.updateSubscription(sub, plan_code: u.plan.plan_code, numberOfTeamMembers: teamMembers.count).promise, do: { result throws -> I in
                        return I.redirect(to: .account(.billing))
                    })
                })
            }
        case .reactivate:
            return try requirePost(csrf: user.data.csrf) {
                return I.onSuccess(promise: user.currentSubscription.promise.map(flatten)) { sub in
                    guard sub.state == .canceled else {
                        throw ServerError(privateMessage: "cancel: no active sub \(user) \(sub)", publicMessage: "Can't find a cancelled subscription.")
                    }
                    return I.onSuccess(promise: recurly.reactivate(sub).promise) { result in
                        switch result {
                        case .success: return I.redirect(to: .account(.thankYou))
                        case .errors(let errs): throw RecurlyErrors(errs)
                        }
                    }
                    
                }
            }
        }
    }
}

extension Route.Account {
    func interpret<I: SwiftTalkInterpreter>(sesssion sess: Session, context: Context, connection c: Lazy<Connection>) throws -> I {
        func teamMembersResponse(_ data: TeamMemberFormData? = nil,_ errors: [ValidationError] = []) throws -> I {
            let renderedForm = addTeamMemberForm().render(data ?? TeamMemberFormData(githubUsername: ""), sess.user.data.csrf, errors)
            let members = try c.get().execute(sess.user.teamMembers)
            return I.write(teamMembersView(context: context, csrf: sess.user.data.csrf, addForm: renderedForm, teamMembers: members))
        }

        switch self {
        case .thankYou:
            let episodesWithProgress = try Episode.all.scoped(for: sess.user.data).withProgress(for: sess.user.id, connection: c)
            var cont = context
            cont.message = ("Thank you for supporting us.", .notice)
            return .write(renderHome(episodes: episodesWithProgress, context: cont))
        case .logout:
            try c.get().execute(sess.user.deleteSession(sess.sessionId))
            return I.redirect(to: .home)
        case .register(let couponCode):
            return I.withPostBody(do: { body in
                guard let result = registerForm(context, couponCode: couponCode).parse(csrf: sess.user.data.csrf, body) else {
                    throw ServerError(privateMessage: "Failed to parse form data to create an account", publicMessage: "Something went wrong during account creation. Please try again.")
                }
                var u = sess.user
                u.data.email = result.email
                u.data.name = result.name
                u.data.confirmedNameAndEmail = true
                let errors = u.data.validate()
                if errors.isEmpty {
                    try c.get().execute(u.update())
                    if sess.premiumAccess {
                        return I.redirect(to: .home)
                    } else {
                        return I.redirect(to: .subscription(.new(couponCode: couponCode)))
                    }
                } else {
                    let result = registerForm(context, couponCode: couponCode).render(result, u.data.csrf, errors)
                    return I.write(result)
                }
            })
        case .profile:
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
                    return I.redirect(to: .account(.profile))
                } else {
                    return I.write(f.render(result, u.data.csrf, errors))
                }
            })
        case .billing:
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
                                throw ServerError(privateMessage: "No coupon for \(r)!", publicMessage: "Something went wrong.")
                            }
                            return (r,c)
                        }
                        let result = billingView(context: context, user: sess.user, subscription: subAndAddOn, invoices: invoicesAndPDFs, billingInfo: billingInfo, redemptions: redemptionsWithCoupon)
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
                    } else if sess.gifterPremiumAccess {
                        return I.write(gifteeBilling(context: context))
                    } else {
                        return I.write(unsubscribedBilling(context: context))
                    }
                })
            }
            return renderBilling(recurlyToken: t)
        case .updatePayment:
            func renderForm(errs: [RecurlyError]) -> I {
                return I.onSuccess(promise: sess.user.billingInfo.promise, do: { billingInfo in
                    let view = updatePaymentView(context: context, data: PaymentViewData(billingInfo, action: Route.account(.updatePayment).path, csrf: sess.user.data.csrf, publicKey: env.recurlyPublicKey, buttonText: "Update", paymentErrors: errs.map { $0.message }))
                    return I.write(view)
                })
            }
            return I.withPostBody(csrf: sess.user.data.csrf, do: { body in
                guard let token = body["billing_info[token]"] else {
                    throw ServerError(privateMessage: "No billing_info[token]", publicMessage: "Something went wrong, please try again.")
                }
                return I.onSuccess(promise: sess.user.updateBillingInfo(token: token).promise, do: { (response: RecurlyResult<BillingInfo>) -> I in
                    switch response {
                    case .success: return I.redirect(to: .account(.updatePayment)) // todo show message?
                    case .errors(let errs): return renderForm(errs: errs)
                    }
                })
            }, or: {
                renderForm(errs: [])
            })
            
        case .teamMembers:
            let csrf = sess.user.data.csrf
            return I.withPostBody(do: { params in
                guard let formData = addTeamMemberForm().parse(csrf: csrf, params), sess.selfPremiumAccess else { return try teamMembersResponse() }
                let promise = github.profile(username: formData.githubUsername).promise
                return I.onComplete(promise: promise) { profile in
                    guard let p = profile else {
                        return try teamMembersResponse(formData, [(field: "github_username", message: "No user with this username exists on GitHub")])
                    }
                    let newUserData = UserData(email: p.email ?? "", githubUID: p.id, githubLogin: p.login, avatarURL: p.avatar_url, name: p.name ?? "")
                    let newUserid = try c.get().execute(newUserData.findOrInsert(uniqueKey: "github_uid", value: p.id))
                    let teamMemberData = TeamMemberData(userId: sess.user.id, teamMemberId: newUserid)
                    guard let _ = try? c.get().execute(teamMemberData.insert) else {
                        return try teamMembersResponse(formData, [(field: "github_username", message: "Team member already exists")])
                    }
                    let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(minutes: 5)
                    try c.get().execute(task)
                    return try teamMembersResponse()
                }
            }, or: {
                return try teamMembersResponse()
            })
        case .deleteTeamMember(let id):
            return try requirePost(csrf: sess.user.data.csrf) {
                try c.get().execute(sess.user.deleteTeamMember(id))
                let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: Date().addingTimeInterval(5*60))
                try c.get().execute(task)
                return try teamMembersResponse()
            }
        }
    }
}

extension Route.Gifts {
    func interpret<I: SwiftTalkInterpreter>(session: Session?, context: Context, connection c: Lazy<Connection>) throws -> I {
        switch self {
        case .home:
            return try I.write(giftHome(plans: Plan.gifts, context: context))
        case .new(let planCode):
            guard let plan = Plan.gifts.first(where: { $0.plan_code == planCode }) else {
                throw ServerError.init(privateMessage: "Illegal plan: \(planCode)", publicMessage: "Couldn't find the plan you selected.")
            }
            return form(giftForm(plan: plan, context: context), initial: GiftStep1Data(planCode: planCode), csrf: sharedCSRF, convert: Gift.fromData, validate: { $0.validate() }, onPost: { gift in
                catchAndDisplayError {
                    let id = try c.get().execute(gift.insert)
                    return I.redirect(to: Route.gift(.pay(id)))
                }
            })
        case .pay(let id):
            guard let gift = try c.get().execute(Row<Gift>.select(id)) else {
                throw ServerError(privateMessage: "No such gift", publicMessage: "Something went wrong, please try again.")
            }
            let plan = try Plan.gifts.first(where: { $0.plan_code == gift.data.planCode }) ?! ServerError.init(privateMessage: "Illegal plan: \(gift.data.planCode)", publicMessage: "Couldn't find the plan you selected.")
            guard gift.data.subscriptionId == nil else {
                throw ServerError(privateMessage: "Already paid \(gift.id)", publicMessage: "You already paid this gift.")
            }
            let f = payGiftForm(plan: plan, gift: gift.data, context: context, route: .gift(.pay(id)))
            return form(f, initial: .init(), csrf: sharedCSRF, validate: { _ in [] }, onPost: { (result: GiftResult) throws in
                let userId = try c.get().execute(UserData(email: result.gifter_email, avatarURL: "", name: "").insert)
                let start = gift.data.sendAt > Date() ? gift.data.sendAt : nil // no start date means starting immediately
                let cr = CreateSubscription(plan_code: plan.plan_code, currency: "USD", coupon_code: nil, starts_at: start, account: .init(account_code: userId, email: result.gifter_email, billing_info: .init(token_id: result.token)))
                return I.onSuccess(promise: recurly.createSubscription(cr).promise, message: "Something went wrong, please try again", do: { sub_ in
                    switch sub_ {
                    case .errors(let messages):
                        log(RecurlyErrors(messages))
                        let theMessages = messages.map { ($0.field ?? "", $0.message) } + [("", "There was a problem with the payment. You have not been charged. Please try again or contact us for assistance.")]
                        let response = giftForm(plan: plan, context: context).render(GiftStep1Data(gifteeEmail: gift.data.gifteeEmail, gifteeName: gift.data.gifteeName, day: "", month: "", year: "", message: gift.data.message, planCode: plan.plan_code), sharedCSRF, theMessages)
                        return I.write(response)
                    case .success(let sub):
                        var copy = gift
                        copy.data.gifterUserId = userId
                        copy.data.subscriptionId = sub.uuid
                        copy.data.gifterEmail = result.gifter_email
                        copy.data.gifterName = result.gifter_name
                        try c.get().execute(copy.update())
                        if start != nil {
                            let email = sendgrid.send(to: result.gifter_email, name: copy.data.gifterName ?? "", subject: "Thank you for gifting Swift Talk", text: copy.data.gifterEmailText)
                            URLSession.shared.load(email) { result in
                                myAssert(result != nil)
                            }
                        }
                        return I.redirect(to: .gift(.thankYou(id)))
                    }
                })
            })
        case .thankYou(let id):
            guard let gift = try c.get().execute(Row<Gift>.select(id)) else {
                throw ServerError(privateMessage: "gift doesn't exist: \(id.uuidString)", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
            }
            
            return I.write(giftThankYou(gift: gift.data, context: context))
        case .redeem(let id):
            guard let gift = try c.get().execute(Row<Gift>.select(id)) else {
                throw ServerError(privateMessage: "gift doesn't exist: \(id.uuidString)", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
            }
            guard let plan = Plan.gifts.first(where: { $0.plan_code == gift.data.planCode }) else {
                throw ServerError(privateMessage: "plan \(gift.data.planCode) for gift \(id.uuidString) does not exist", publicMessage: "This gift subscription doesn't exist. Please get in touch to resolve this issue.")
            }
            if session?.premiumAccess == true {
                return try I.write(redeemGiftAlreadySubscribed(context: context))
            } else if let user = session?.user {
                var g = gift
                g.data.gifteeUserId = user.id
                try c.get().execute(g.update())

                var u = user
                if !u.data.confirmedNameAndEmail {
                    u.data.name = g.data.gifteeName
                    u.data.email = g.data.gifteeEmail
                    try c.get().execute(u.update())
                }
                return I.redirect(to: Route.home) // could be a special thank you page for the redeemer
            } else {
                return I.write(try redeemGiftSub(context: context, gift: gift, plan: plan))
            }
        }
    }
}

let sharedCSRF = CSRFToken(UUID(uuidString: "F5F6C2AE-85CB-4989-B0BF-F471CC92E3FF")!)
