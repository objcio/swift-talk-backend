//
//  Home.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation

func renderHome(session: Session?) -> Node {
    let header = pageHeader(HeaderContent.other(header: "Swift Talk", blurb: "A weekly video series on Swift programming.", extraClasses: "ms4"))
    let firstEpisode = Episode.all.first!
    let recentEpisodes: Node = .section(classes: "container", [
        Node.header(attributes: ["class": "mb+"], [
            .h2([.text("Recent Episodes")], attributes: ["class": "inline-block bold color-black"]),
            .link(to: .episodes, [.text("See All")], attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-under"])
            ]),
        .div(classes: "m-cols flex flex-wrap", [
            .div(classes: "mb++ p-col width-full l+|width-1/2", [
                firstEpisode.render(Episode.ViewOptions(featured: true, synopsis: true, canWatch: session.premiumAccess || !firstEpisode.subscription_only))
                ]),
            .div(classes: "p-col width-full l+|width-1/2", [
                .div(classes: "s+|cols s+|cols--2n",
                     Episode.all[1..<5].map { ep in
                        .div(classes: "mb++ s+|col s+|width-1/2", [
                            ep.render(Episode.ViewOptions(synopsis: false, canWatch: session.premiumAccess || !ep.subscription_only))
                            ])
                    }
                )
                ])
            ])
        ])
    let collections: Node = .section(attributes: ["class": "container"], [
        .header(attributes: ["class": "mb+"], [
            .h2([.text("Collections")], attributes: ["class": "inline-block bold lh-100 mb---"]),
            .link(to: .collections, [.text("Show Contents")], attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-underline"]),
            .p(attributes: ["class": "lh-125 color-gray-60"], [
                .text("Browse all Swift Talk episodes by topic.")
                ])
            ]),
        .ul(attributes: ["class": "cols s+|cols--2n l+|cols--3n"], Collection.all.map { coll in
            Node.li(attributes: ["class": "col width-full s+|width-1/2 l+|width-1/3 mb++"], coll.render())
        })
        ])
    return LayoutConfig(session: session, contents: [header, recentEpisodes, collections]).layout
}

