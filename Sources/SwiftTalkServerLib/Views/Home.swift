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
    var recentNodes: [Node] = [
        .header(classes: "mb+", [
            .h2(classes: "inline-block bold color-black", [.text("Recent Episodes")]),
            .link(to: .episodes, classes: "inline-block ms-1 ml- color-blue no-decoration hover-under", [.text("See All")])
        ])
    ]
    if episodes.count >= 5 {
        let slice = episodes[0..<5]
        let featured = slice[0]
        recentNodes.append(.withSession { session in
            .div(classes: "m-cols flex flex-wrap", [
                .div(classes: "mb++ p-col width-full l+|width-1/2", [
                    featured.episode.render(Episode.ViewOptions(featured: true, synopsis: true, watched: featured.watched, canWatch: featured.episode.canWatch(session: session)))
                ]),
                .div(classes: "p-col width-full l+|width-1/2", [
                    .div(classes: "s+|cols s+|cols--2n",
                        slice.dropFirst().map { e in
                            .div(classes: "mb++ s+|col s+|width-1/2", [
                                e.episode.render(Episode.ViewOptions(synopsis: false, watched: e.watched, canWatch: e.episode.canWatch(session: session)))
                            ])
                        }
                    )
                ])
            ])
        })
    }
    let recentEpisodes = Node.section(classes: "container", recentNodes)
    let collections = Node.section(classes: "container", [
        .header(classes: "mb+", [
            .h2(classes: "inline-block bold lh-100 mb---", [.text("Collections")]),
            .link(to: .collections, classes: "inline-block ms-1 ml- color-blue no-decoration hover-underline", [.text("Show Contents")]),
            .p(classes: "lh-125 color-gray-60", [
                .text("Browse all Swift Talk episodes by topic.")
                ])
            ]),
        .ul(classes: "cols s+|cols--2n l+|cols--3n", Collection.all.map { coll in
            .li(classes: "col width-full s+|width-1/2 l+|width-1/3 mb++", coll.render())
        })
    ])
    return LayoutConfig(contents: [header, recentEpisodes, collections]).layout
}

