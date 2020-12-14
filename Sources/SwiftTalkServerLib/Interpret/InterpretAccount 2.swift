//
//  InterpretAccount.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import Promise
import Database
import WebServer
import Base

extension ProfileFormData {
    init(_ data: UserData) {
        email = data.email
        name = data.name
    }
}

extension Route.Account {
    func interpret<I: STResponse>() throws -> I where I.Env == STRequestEnvironment {
        return .requireSession { try self.interpret(session: $0)}
    }
    
    private func interpret<I: STResponse>(session sess: Session) throws -> I where I.Env == STRequestEnvironment {

        func editAccount(form: Form<ProfileFormData, STRequestEnvironment>, role: UserData.Role, cont: @escaping () -> Route) -> I {
            func updateAndRedirect(_ user: Row<UserData>) -> I {
                return .query(user.update()) { _ in
                    return .redirect(to: cont())
                }
            }
            
            return .form(form, initial: ProfileFormData(sess.user.data), convert: { profile in
                var u = sess.user
                u.data.email = profile.email
                u.data.name = profile.name
                u.data.confirmedNameAndEmail = true
                u.data.role = role
                let errors = u.data.validate()
                if errors.isEmpty {
                    return .left(u)
                } else {
                    return .right(errors)
                }
            }, onPost: { user in
                .onSuccess(promise: recurly.account(with: sess.user.id).promise, do: { _ in
                    .onSuccess(promise: recurly.updateAccount(accountCode: sess.user.id, email: user.data.email).promise, do: { (a: Account?) -> I in
                        updateAndRedirect(user)
                    }, else: {
                        .write(html: form.render(ProfileFormData(user.data), [(field: "", message: "An error occurred while updating your account profile. Please try again later.")]))
                    })
                }, else: {
                    updateAndRedirect(user)
                })
            })
        }
        
        switch self {
        case .logout:
            return I.query(sess.user.deleteSession(sess.sessionId)) {
                return I.redirect(to: .home)
            }
        case let .register(couponCode, planCode, team):
            let role: UserData.Role = team ? .teamManager : .user
            return editAccount(form: registerForm(couponCode: couponCode, planCode: planCode, team: team), role: role) {
                return sess.premiumAccess ? .home : .subscription(.new(couponCode: couponCode, planCode: planCode, team: team))
            }
        case .profile:
            return editAccount(form: accountForm(), role: sess.user.data.role, cont: { .account(.profile) })

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
                return .onSuccess(promise: promise, do: { p in
                    let (sub, invoicesAndPDFs, redemptions, billingInfo, coupons) = p
                    func cont(subAndAddOn: (Subscription, Plan.AddOn)?) throws -> I {
                        let redemptionsWithCoupon = try redemptions.map { (r) -> (Redemption, Coupon) in
                            let c = try coupons.first(where: { $0.matches(r.coupon_code) }) ?!
                                ServerError(privateMessage: "No coupon for \(r)!", publicMessage: "Something went wrong while loading your account details. Please contact us at \(email) to resolve this issue.")
                            return (r,c)
                        }
                        let result = billingView(subscription: subAndAddOn, invoices: invoicesAndPDFs, billingInfo: billingInfo, redemptions: redemptionsWithCoupon)
                        return .write(html: result)
                    }
                    if let s = sub, let p = Plan.all.first(where: { $0.plan_code == s.plan.plan_code }) {
                        return .onSuccess(promise: p.teamMemberAddOn.promise, do: { addOn in
                            try cont(subAndAddOn: (s, addOn))
                        })
                    } else {
                        return try cont(subAndAddOn: nil)
                    }
                })
            }
            guard let t = sess.user.data.recurlyHostedLoginToken else {
                return .onSuccess(promise: sess.user.account.promise, do: { acc in
                    user.data.recurlyHostedLoginToken = acc.hosted_login_token
                    return .query(user.update()) {
                        renderBilling(recurlyToken: acc.hosted_login_token)
                    }
                }, else: {
                    if sess.teamMemberPremiumAccess {
                        return .write(html: billingLayout(teamMemberBillingContent()))
                    } else if sess.gifterPremiumAccess {
                        return .write(html: billingLayout(gifteeBillingContent()))
                    } else {
                        return .write(html: billingLayout(unsubscribedBillingContent()))
                    }
                })
            }
            return renderBilling(recurlyToken: t)
            
        case .updatePayment:
            // todo use the form helper
            func renderForm(error: RecurlyError?) -> I {
                return .onSuccess(promise: sess.user.billingInfo.promise, do: { billingInfo in
                    let data = SubscriptionFormData(error: error)
                    let view: Node
                    if let b = billingInfo {
                        view = updatePaymentView(data: data, initial: b)
                    } else {
                        view  = noBillingInfoView()
                    }
                    return .write(html: view)
                })
            }
            return .verifiedPost(do: { body in
                let token = try body["billing_info[token]"] ?!
                    ServerError(privateMessage: "No billing_info[token]")
                return .onSuccess(promise: sess.user.updateBillingInfo(token: token).promise, do: { (response: RecurlyResult<BillingInfo>) -> I in
                    switch response {
                    case .success: return .redirect(to: .account(.updatePayment)) // todo show message?
                    case .error(let error): return renderForm(error: error)
                    }
                })
            }, or: {
                renderForm(error: nil)
            })
            
        case .teamMembers:
            let signupLink = Route.signup(.teamMember(token: sess.user.data.teamToken)).url
            return I.query(sess.user.teamMembers) { members in
                return I.onSuccess(promise: sess.user.currentSubscription.promise, do: { sub in
                    guard let s = sub, let p = Plan.all.first(where: { $0.plan_code == s.plan.plan_code }) else {
                        throw ServerError(privateMessage: "Can't get sub or plan: \(String(describing: sub))")
                    }
                    return I.onSuccess(promise: p.teamMemberAddOn.promise, do: { addOn in
                        let prettyAmount: String?
                        if addOn.unit_amount_in_cents.usdCents > 0 {
                            prettyAmount = "\(addOn.unit_amount_in_cents.plainText) \(p.prettyInterval)"
                        } else {
                            prettyAmount = nil
                        }
                        return I.write(html: teamMembersView(teamMembers: members, price: prettyAmount, signupLink: signupLink))
                    })
                })
            }
        
        case .invalidateTeamToken:
            var user = sess.user
            user.data.teamToken = UUID()
            return .query(user.update()) { .redirect(to: .account(.teamMembers)) }
        
        case .deleteTeamMember(let id):
            return .verifiedPost { _ in
                .query(sess.user.deleteTeamMember(teamMemberId: id, userId: sess.user.id)) {
                    let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: globals.currentDate().addingTimeInterval(5*60))
                    return .query(task) {
                        .redirect(to: .account(.teamMembers))
                    }
                }
            }
        }
    }
}
