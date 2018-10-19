//
//  Home.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation

func renderHome(context: Context) -> Node {
    let header = pageHeader(HeaderContent.other(header: "Swift Talk", blurb: "A weekly video series on Swift programming.", extraClasses: "ms4"))
    var recentNodes = [
        Node.header(attributes: ["class": "mb+"], [
            .h2([.text("Recent Episodes")], attributes: ["class": "inline-block bold color-black"]),
            .link(to: .episodes, [.text("See All")], attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-under"])
        ])
    ]
    let scoped = Episode.scoped(for: context.session?.user.data)
    if scoped.count >= 5 {
        let episodes = scoped[0..<5]
        let firstEpisode = episodes[0]
        recentNodes.append(.div(classes: "m-cols flex flex-wrap", [
            .div(classes: "mb++ p-col width-full l+|width-1/2", [
                firstEpisode.render(Episode.ViewOptions(featured: true, synopsis: true, canWatch: context.session.premiumAccess || !firstEpisode.subscription_only))
            ]),
            .div(classes: "p-col width-full l+|width-1/2", [
                .div(classes: "s+|cols s+|cols--2n",
                    episodes.dropFirst().map { ep in
                        .div(classes: "mb++ s+|col s+|width-1/2", [
                            ep.render(Episode.ViewOptions(synopsis: false, canWatch: context.session.premiumAccess || !ep.subscription_only))
                        ])
                    }
                )
            ])
        ]))
    }
    let recentEpisodes: Node = .section(classes: "container", recentNodes)
    let collections: Node = .section(attributes: ["class": "container"], [
        .header(attributes: ["class": "mb+"], [
            .h2([.text("Collections")], attributes: ["class": "inline-block bold lh-100 mb---"]),
            .link(to: .collections, [.text("Show Contents")], attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-underline"]),
            .p(attributes: ["class": "lh-125 color-gray-60"], [
                .text("Browse all Swift Talk episodes by topic.")
                ])
            ]),
        .ul(attributes: ["class": "cols s+|cols--2n l+|cols--3n"], Collection.all.map { coll in
            Node.li(attributes: ["class": "col width-full s+|width-1/2 l+|width-1/3 mb++"], coll.render(context: context))
        })
        ])
    return LayoutConfig(context: context, contents: [header, recentEpisodes, collections]).layout
}

