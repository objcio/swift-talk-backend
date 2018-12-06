//
//  Gifts.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 06.12.18.
//

import Foundation

func giftForm(submitTitle: String, action: Route) -> Form<GiftStep1> {
    return Form(parse: { dict in
        // todo parse date
        dump(dict)
        guard let gifterEmail = dict["gifter_email"],
            let gifterName = dict["gifter_name"],
        	let gifteeEmail = dict["giftee_email"],
            let message = dict["message"],
            let gifteeName = dict["giftee_name"]
            else { return nil }
        return GiftStep1(gifterEmail: gifterEmail, gifterName: gifterName, gifteeEmail: gifteeEmail, gifteeName: gifteeName, sendAt: Date() // todo
            , message: message)
        
    }, render: { data, csrf, errors in
        let form = FormView(fields: [
            FormView.Field(id: "gifter_name", title: "Your Name", value: data.gifterName),
            FormView.Field(id: "gifter_email", title: "Your Email", value: data.gifterEmail),
            FormView.Field(id: "giftee_name", title: "The Recipients' Name", value: data.gifteeName),
            FormView.Field(id: "giftee_email", title: "The Recipients' Email", value: data.gifteeEmail),
            FormView.Field(id: "message", title: "Your Message", value: data.message)
            ], submitTitle: submitTitle, action: action, errors: errors)
        return .div(form.renderStacked(csrf: csrf))
    })
}

func giftForm(context: Context) -> Form<GiftStep1> {
    // todo button color required fields.
    let form = giftForm(submitTitle: "Step 2: Choose Plan", action: .newGift)
    return form.wrap { (node: Node) -> Node in
        let result: Node = LayoutConfig(context: context, contents: [
            .div(classes: "container", [
                Node.h2(classes: "color-blue bold ms2 mb", [.text("New Gift Subscription (Step 1/2)")]),
                node
            ])
        ]).layout
        return result
    }
}

struct RecurlyToken {
    var value: String
}

func payGiftForm(context: Context, route: Route) -> Form<RecurlyToken> {
    return Form.init(parse: { dict in
        guard let d = dict["billing_info[token]"] else { return nil }
        return RecurlyToken(value: d)
    }, render: { (_, csrf, errs) -> Node in
        let data = NewGiftSubscriptionData(action: route.path, public_key: env.recurlyPublicKey, plans: Plan.gifts.map { .init($0) }, payment_errors: errs.map { "\($0.field): \($0.message)" }, method: .post, csrf: csrf)
        return LayoutConfig(context: context,  contents: [
            .header([
                .div(classes: "container-h pb+ pt+", [
                    .h1(classes: "ms4 color-blue bold", ["Complete Your Purchase"])
                    ])
                ]),
            .div(classes: "container", [
                ReactComponent.newGiftSubscription.build(data)
                ])
		], includeRecurlyJS: true).layoutForCheckout
    })
}
