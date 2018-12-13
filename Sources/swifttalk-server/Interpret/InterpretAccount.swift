//
//  InterpretAccount.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import PostgreSQL

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
            return I.form(f, initial: data, csrf: u.data.csrf, validate: { _ in [] }, onPost: { result in
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
                return I.onCompleteThrows(promise: promise) { profile in
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
            return I.withPostBody (csrf: sess.user.data.csrf) { _ in
                try c.get().execute(sess.user.deleteTeamMember(id))
                let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: Date().addingTimeInterval(5*60))
                try c.get().execute(task)
                return try teamMembersResponse()
            }
        }
    }
}
