//
//  InterpretAccount.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import PostgreSQL

extension ProfileFormData {
    init(_ data: UserData) {
        email = data.email
        name = data.name
    }
}

extension Route.Account {
    func interpret<I: Interp>() throws -> I {
        return I.requireSession { try self.interpret2(session: $0)}
    }
    
    private func interpret2<I: Interp>(session sess: Session) throws -> I {
        func teamMembersResponse(_ data: TeamMemberFormData? = nil,_ errors: [ValidationError] = []) throws -> I {
            let renderedForm = addTeamMemberForm().render(data ?? TeamMemberFormData(githubUsername: ""), errors)
            return I.query(sess.user.teamMembers) { members in
                I.write(teamMembersView(addForm: renderedForm, teamMembers: members))
            }
        }
        
        switch self {
        case .thankYou:
            return I.withConnection { c in
                // todo: change how we load the episodes (should be a Query<X>, rather than take a connection)
                let episodesWithProgress = try Episode.all.scoped(for: sess.user.data).withProgress(for: sess.user.id, connection: c)
                // todo: flash: "Thank you for supporting us
                return .write(renderHome(episodes: episodesWithProgress))
            }
        case .logout:
            return I.query(sess.user.deleteSession(sess.sessionId)) {
                return I.redirect(to: .home)
            }
        case .register(let couponCode):
            return I.form(registerForm(couponCode: couponCode), initial: ProfileFormData(sess.user.data), convert: { profile in
                var u = sess.user
                u.data.email = profile.email
                u.data.name = profile.name
                u.data.confirmedNameAndEmail = true
                let errors = u.data.validate()
                if errors.isEmpty {
                    return .left(u)
                } else {
                    return .right(errors)
                }
            }, onPost: { (user: Row<UserData>) in
                return I.query(user.update()) {
                    if sess.premiumAccess {
                        return I.redirect(to: .home)
                    } else {
                        return I.redirect(to: .subscription(.new(couponCode: couponCode)))
                    }
                }
            })
        case .profile:
            var u = sess.user
            let data = ProfileFormData(email: u.data.email, name: u.data.name)
            let f = accountForm()
            return I.form(f, initial: data, validate: { _ in [] }, onPost: { result in
                // todo: this is almost the same as the new account logic... can we abstract this?
                u.data.email = result.email
                u.data.name = result.name
                u.data.confirmedNameAndEmail = true
                let errors = u.data.validate()
                if errors.isEmpty {
                    return I.query(u.update()) {
                    	I.redirect(to: .account(.profile))
                    }
                } else {
                    return I.write(f.render(result, errors))
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
                            guard let c = coupons.first(where: { $0.matches(r.coupon_code) }) else {
                                throw ServerError(privateMessage: "No coupon for \(r)!", publicMessage: "Something went wrong while loading your account details. Please contact us at \(email) to resolve this issue.")
                            }
                            return (r,c)
                        }
                        let result = billingView(user: sess.user, subscription: subAndAddOn, invoices: invoicesAndPDFs, billingInfo: billingInfo, redemptions: redemptionsWithCoupon)
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
                    return I.query(user.update()) {
                    	renderBilling(recurlyToken: acc.hosted_login_token)
                    }
                }, else: {
                    if sess.teamMemberPremiumAccess {
                        return I.write(teamMemberBilling())
                    } else if sess.gifterPremiumAccess {
                        return I.write(gifteeBilling())
                    } else {
                        return I.write(unsubscribedBilling())
                    }
                })
            }
            return renderBilling(recurlyToken: t)
        case .updatePayment:
            // todo use the form helper
            func renderForm(errs: [RecurlyError]) -> I {
                return I.onSuccess(promise: sess.user.billingInfo.promise, do: { billingInfo in
                    let view = updatePaymentView(data: PaymentViewData(billingInfo, action: Route.account(.updatePayment).path, csrf: sess.user.data.csrf, publicKey: env.recurlyPublicKey, buttonText: "Update", paymentErrors: errs.map { $0.message }))
                    return I.write(view)
                })
            }
            return I.verifiedPost(do: { body in
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
            // todo use the form helper
            return I.verifiedPost(do: { params in
                guard let formData = addTeamMemberForm().parse(params), sess.selfPremiumAccess else { return try teamMembersResponse() }
                let promise = github.profile(username: formData.githubUsername).promise
                return I.onCompleteOrCatch(promise: promise) { profile in
                    guard let p = profile else {
                        return try teamMembersResponse(formData, [(field: "github_username", message: "No user with this username exists on GitHub")])
                    }
                    let newUserData = UserData(email: p.email ?? "", githubUID: p.id, githubLogin: p.login, avatarURL: p.avatar_url, name: p.name ?? "")
                    return I.query(newUserData.findOrInsert(uniqueKey: "github_uid", value: p.id)) { (newUserId: UUID) in
                        let teamMemberData = TeamMemberData(userId: sess.user.id, teamMemberId: newUserId)
                        return I.execute(teamMemberData.insert) { (result: Either<UUID, Error>) in
                            switch result {
                            case .right: return try teamMembersResponse(formData, [(field: "github_username", message: "Team member already exists")])
                            case .left:
                                let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(minutes: 5)
                                return I.query(task) {
                                    try teamMembersResponse()
                                }

                            }
                        }
                    }
                }
            }, or: {
                return try teamMembersResponse()
            })
        case .deleteTeamMember(let id):
            return I.verifiedPost { _ in
                I.query(sess.user.deleteTeamMember(id)) {
                    let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: globals.currentDate().addingTimeInterval(5*60))
                    return I.query(task) {
                    	try teamMembersResponse()
                    }
                }
            }
        }
    }
}
