//
//  Home.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML


func renderHome(episodes: [EpisodeWithProgress]) -> Node {
    let header = pageHeader(HeaderContent.other(header: "Swift Talk", blurb: "A weekly video series on Swift programming.", extraClasses: "ms4"))
    var recentNodes = [
        Node.header(attributes: ["class": "mb+"], [
            .h2(attributes: ["class": "inline-block bold color-black"], [.text("Recent Episodes")]),
            .link(to: .episodes, attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-under"], [.text("See All")])
        ])
    ]
    if episodes.count >= 5 {
        let slice = episodes[0..<5]
        let featured = slice[0]
        recentNodes.append(.withContext { context in
            .div(classes: "m-cols flex flex-wrap", [
                .div(classes: "mb++ p-col width-full l+|width-1/2", [
                    featured.episode.render(Episode.ViewOptions(featured: true, synopsis: true, watched: featured.watched, canWatch: featured.episode.canWatch(session: context.session)))
                ]),
                .div(classes: "p-col width-full l+|width-1/2", [
                    .div(classes: "s+|cols s+|cols--2n",
                        slice.dropFirst().map { e in
                            .div(classes: "mb++ s+|col s+|width-1/2", [
                                e.episode.render(Episode.ViewOptions(synopsis: false, watched: e.watched, canWatch: e.episode.canWatch(session: context.session)))
                            ])
                        }
                    )
                ])
        ])})
    }
    let recentEpisodes: Node = .section(classes: "container", recentNodes)
    let collections: Node = .section(attributes: ["class": "container"], [
        .header(attributes: ["class": "mb+"], [
            .h2(attributes: ["class": "inline-block bold lh-100 mb---"], [.text("Collections")]),
            .link(to: .collections, attributes: ["class": "inline-block ms-1 ml- color-blue no-decoration hover-underline"], [.text("Show Contents")]),
            .p(attributes: ["class": "lh-125 color-gray-60"], [
                .text("Browse all Swift Talk episodes by topic.")
                ])
            ]),
        .ul(attributes: ["class": "cols s+|cols--2n l+|cols--3n"], Collection.all.map { coll in
            Node.li(attributes: ["class": "col width-full s+|width-1/2 l+|width-1/3 mb++"], coll.render())
        })
        ])
    return LayoutConfig(contents: [header, recentEpisodes, collections]).layout
}

