//
//  3DSecure.swift
//  Backtrace
//
//  Created by Florian Kugler on 27-08-2019.
//

import Foundation


func threeDSecureView(threeDActionToken: String, success: ThreeDSuccessRoute, otherPaymentMethod: Route) throws -> Node {
    return LayoutConfig(contents: [
        .header([
            .div(class: "container-h pb+ pt+", [
                .h1(class: "ms4 color-blue bold", ["3-D Secure Authentication"])
            ]),
            .div(class: "container", attributes: ["id": "threeDSecureContainer"], [
                .p(class: "c-text mb++", ["Additional authentication is required to complete your purchase."])
            ])
        ]),
        .script(code: """
            window.addEventListener('DOMContentLoaded', (event) => {
                recurly.configure({ publicKey: '\(env.recurlyPublicKey)' });
                const container = document.querySelector('#threeDSecureContainer');
                const risk = recurly.Risk();
                const threeDSecure = risk.ThreeDSecure({ actionTokenId: '\(threeDActionToken)' });
                threeDSecure.on('error', err => {
                    container.innerHTML = `
                        <p class="c-text">Something went wrong during 3-D Secure authentication. Please retry or <a href="\(otherPaymentMethod.path)">use a different payment method</a>.</p>
                    `
                });
                threeDSecure.on('token', token => {
                    window.location.assign('\(success.route.path)'.replace('\(ThreeDSuccessRoute.threeDSecureResultTokenPlaceholder)', token.id));
                });
                threeDSecure.attach(container);
            });
            """),
    ], includeRecurlyJS: true).layoutForCheckout
}
