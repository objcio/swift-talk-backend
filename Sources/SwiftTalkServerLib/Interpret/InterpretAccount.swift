////
////  InterpretAccount.swift
////  swifttalk-server
////
////  Created by Chris Eidhof on 13.12.18.
////
//
//import Foundation
//import Promise
//import Database
//
//
//extension ProfileFormData {
//    init(_ data: UserData) {
//        email = data.email
//        name = data.name
//    }
//}
//
//extension Route.Account {
//    func interpret<I: Interp>() throws -> I where I.RE == STRequestEnvironment {
//        return I.requireSession { try self.interpret2(session: $0)}
//    }
//    
//    private func interpret2<I: Interp>(session sess: Session) throws -> I where I.RE == STRequestEnvironment {
//        switch self {
//        
//        case .logout:
//            return I.query(sess.user.deleteSession(sess.sessionId)) {
//                return I.redirect(to: .home)
//            }
//            
//        case let .register(couponCode, team):
//            return I.form(registerForm(couponCode: couponCode, team: team), initial: ProfileFormData(sess.user.data), convert: { profile in
//                var u = sess.user
//                u.data.email = profile.email
//                u.data.name = profile.name
//                u.data.confirmedNameAndEmail = true
//                u.data.role = team ? .teamManager : .user
//                let errors = u.data.validate()
//                if errors.isEmpty {
//                    return .left(u)
//                } else {
//                    return .right(errors)
//                }
//            }, onPost: { (user: Row<UserData>) in
//                return I.query(user.update()) {
//                    if sess.premiumAccess {
//                        return I.redirect(to: .home)
//                    } else {
//                        return I.redirect(to: .subscription(.new(couponCode: couponCode, team: team)))
//                    }
//                }
//            })
//            
//        case .profile:
//            var u = sess.user
//            let data = ProfileFormData(email: u.data.email, name: u.data.name)
//            let f = accountForm()
//            return I.form(f, initial: data, validate: { _ in [] }, onPost: { result in
//                // todo: this is almost the same as the new account logic... can we abstract this?
//                u.data.email = result.email
//                u.data.name = result.name
//                u.data.confirmedNameAndEmail = true
//                let errors = u.data.validate()
//                if errors.isEmpty {
//                    return I.onSuccess(promise: recurly.updateAccount(accountCode: u.id, email: u.data.email).promise, do: { _ in
//                        I.query(u.update()) { _ in
//                            I.redirect(to: .account(.profile))
//                        }
//                    }, else: {
//                        I.write(f.render(data, [(field: "", message: "An error occurred while updating your account profile. Please try again later.")]))
//                    })
//                } else {
//                    return I.write(f.render(result, errors))
//                }
//            })
//            
//        case .billing:
//            var user = sess.user
//            func renderBilling(recurlyToken: String) -> I {
//                let invoicesAndPDFs = sess.user.invoices.promise.map { invoices in
//                    return invoices?.map { invoice in
//                        (invoice, recurly.pdfURL(invoice: invoice, hostedLoginToken: recurlyToken))
//                    }
//                }
//                let redemptions = sess.user.redemptions.promise.map { r in
//                    r?.filter { $0.state == "active" }
//                }
//                let promise = zip(sess.user.currentSubscription.promise, invoicesAndPDFs, redemptions, sess.user.billingInfo.promise, recurly.coupons().promise).map(zip)
//                return I.onSuccess(promise: promise, do: { p in
//                    let (sub, invoicesAndPDFs, redemptions, billingInfo, coupons) = p
//                    func cont(subAndAddOn: (Subscription, Plan.AddOn)?) throws -> I {
//                        let redemptionsWithCoupon = try redemptions.map { (r) -> (Redemption, Coupon) in
//                            guard let c = coupons.first(where: { $0.matches(r.coupon_code) }) else {
//                                throw ServerError(privateMessage: "No coupon for \(r)!", publicMessage: "Something went wrong while loading your account details. Please contact us at \(email) to resolve this issue.")
//                            }
//                            return (r,c)
//                        }
//                        let result = billingView(subscription: subAndAddOn, invoices: invoicesAndPDFs, billingInfo: billingInfo, redemptions: redemptionsWithCoupon)
//                        return I.write(result)
//                    }
//                    if let s = sub, let p = Plan.all.first(where: { $0.plan_code == s.plan.plan_code }) {
//                        return I.onSuccess(promise: p.teamMemberAddOn.promise, do: { addOn in
//                            try cont(subAndAddOn: (s, addOn))
//                        })
//                    } else {
//                        return try cont(subAndAddOn: nil)
//                    }
//                })
//            }
//            guard let t = sess.user.data.recurlyHostedLoginToken else {
//                return I.onSuccess(promise: sess.user.account.promise, do: { acc in
//                    user.data.recurlyHostedLoginToken = acc.hosted_login_token
//                    return I.query(user.update()) {
//                        renderBilling(recurlyToken: acc.hosted_login_token)
//                    }
//                }, else: {
//                    if sess.teamMemberPremiumAccess {
//                        return I.write(billingLayout(teamMemberBillingContent()))
//                    } else if sess.gifterPremiumAccess {
//                        return I.write(billingLayout(gifteeBillingContent()))
//                    } else {
//                        return I.write(billingLayout(unsubscribedBillingContent()))
//                    }
//                })
//            }
//            return renderBilling(recurlyToken: t)
//            
//        case .updatePayment:
//            // todo use the form helper
//            func renderForm(errs: [RecurlyError]) -> I {
//                return I.onSuccess(promise: sess.user.billingInfo.promise, do: { billingInfo in
//                    let view = updatePaymentView(data: PaymentViewData(billingInfo, action: Route.account(.updatePayment).path, csrf: sess.user.data.csrfToken, publicKey: env.recurlyPublicKey, buttonText: "Update", paymentErrors: errs.map { $0.message }))
//                    return I.write(view)
//                })
//            }
//            return I.verifiedPost(do: { body in
//                guard let token = body["billing_info[token]"] else {
//                    throw ServerError(privateMessage: "No billing_info[token]", publicMessage: "Something went wrong, please try again.")
//                }
//                return I.onSuccess(promise: sess.user.updateBillingInfo(token: token).promise, do: { (response: RecurlyResult<BillingInfo>) -> I in
//                    switch response {
//                    case .success: return I.redirect(to: .account(.updatePayment)) // todo show message?
//                    case .errors(let errs): return renderForm(errs: errs)
//                    }
//                })
//            }, or: {
//                renderForm(errs: [])
//            })
//            
//        case .teamMembers:
//            let signupLink = Route.signup(.teamMember(token: sess.user.data.teamToken)).url
//            return I.query(sess.user.teamMembers) { members in
//                I.write(teamMembersView(teamMembers: members, signupLink: signupLink))
//            }
//        
//        case .invalidateTeamToken:
//            var user = sess.user
//            user.data.teamToken = UUID()
//            return I.query(user.update()) { I.redirect(to: .account(.teamMembers)) }
//        
//        case .deleteTeamMember(let id):
//            return I.verifiedPost { _ in
//                I.query(sess.user.deleteTeamMember(teamMemberId: id, userId: sess.user.id)) {
//                    let task = Task.syncTeamMembersWithRecurly(userId: sess.user.id).schedule(at: globals.currentDate().addingTimeInterval(5*60))
//                    return I.query(task) {
//                        I.redirect(to: .account(.teamMembers))
//                    }
//                }
//            }
//        }
//    }
//}
