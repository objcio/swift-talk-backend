//
//  Home.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML


func renderHome(episodes: [EpisodeWithProgress]) -> Node {
    let metaDescription = "A weekly video series on Swift programming by Chris Eidhof and Florian Kugler. objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development."
    let header = pageHeader(HeaderContent.other(header: "Swift Talk", blurb: "A weekly video series on Swift programming.", extraClasses: "ms4"))
    var recentNodes: [Node] = [
        .header(class: "mb+", [
            .h2(class: "inline-block bold color-black", ["Recent Episodes"]),
            .link(to: .episodes, class: "inline-block ms-1 ml- color-blue no-decoration hover-under", ["See All"])
        ])
    ]
    var projects: [Node] = Episode.allGroupedByProject.map { pv in
        switch pv {
        case let .single(ep):
            return Node.p([
                Node.text("Single: \(ep.number) \(ep.title)")
            ])
        case let .multiple(eps):
            return Node.p([
                Node.text("Multiple \(eps[0].theProject!.title): \(eps.map { "\($0.number) \($0.title)" }.joined(separator: ", "))")
            ])
        }
    }
    let projectsView = Node.section(class: "container", projects)

    if episodes.count >= 5 {
        let slice = episodes[0..<5]
        let featured = slice[0]
        recentNodes.append(.withSession { session in
            .div(class: "m-cols flex flex-wrap", [
                .div(class: "mb++ p-col width-full l+|width-1/2", [
                    featured.episode.render(Episode.ViewOptions(featured: true, synopsis: true, watched: featured.watched, canWatch: featured.episode.canWatch(session: session)))
                ]),
                .div(class: "p-col width-full l+|width-1/2", [
                    .div(class: "s+|cols s+|cols--2n",
                        slice.dropFirst().map { e in
                            .div(class: "mb++ s+|col s+|width-1/2", [
                                e.episode.render(Episode.ViewOptions(synopsis: false, watched: e.watched, canWatch: e.episode.canWatch(session: session)))
                            ])
                        }
                    )
                ])
            ])
        })
    }
    let recentEpisodes = Node.section(class: "container", recentNodes)
    let collections = Node.section(class: "container", [
        .header(class: "mb+", [
            .h2(class: "inline-block bold lh-100 mb---", [.text("Collections")]),
            .link(to: .collections, class: "inline-block ms-1 ml- color-blue no-decoration hover-underline", ["Show Contents"]),
            .p(class: "lh-125 color-gray-60", [
                "Browse all Swift Talk episodes by topic."
            ])
            ]),
        .ul(class: "cols s+|cols--2n l+|cols--3n", Collection.all.map { coll in
            .li(class: "col width-full s+|width-1/2 l+|width-1/3 mb++", coll.render())
        })
    ])
    return LayoutConfig(contents: [header, projectsView, recentEpisodes, collections], description: metaDescription).layout
}

