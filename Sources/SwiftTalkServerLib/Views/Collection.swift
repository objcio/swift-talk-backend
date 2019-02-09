//
//  Collection.swift
//  Bits
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML


func index(_ items: [Collection]) -> Node {
    let lis: [Node] = items.map({ (coll: Collection) -> Node in
        return .li(classes: "col width-full s+|width-1/2 l+|width-1/3 mb++", coll.render(.init(episodes: true)))
    })
    return LayoutConfig(contents: [
        pageHeader(HeaderContent.link(header: "All Collections", backlink: .home, label: "Swift Talk")),
        .div(classes: "container pb0", [
            .h2(classes: "bold lh-100 mb+", [.text("\(items.count) Collections")]),
            .ul(classes: "cols s+|cols--2n l+|cols--3n", lis)
        ])
    ]).layout
}

extension Collection {
    func show(episodes: [EpisodeWithProgress]) -> Node {
        let bgImage = "background-image: url('/assets/images/collections/\(title)@4x.png');"
        return LayoutConfig(contents: [
            .div(attributes: ["class": "pattern-illustration overflow-hidden", "style": bgImage], [
                .div(classes: "wrapper", [
                    .header(classes: "offset-content offset-header pv++ bgcolor-white", [
                        .p(classes: "ms1 color-gray-70 links clearfix", [
                            .link(to: .home, classes: "bold", [.text("Swift Talk")]),
                            .raw("&#8202;"),
                            .link(to: .collections, classes: "opacity: 90", [.text("Collection")])
                        ]),
                        .h2(classes: "ms5 bold color-black mt--- lh-110 mb-", [.text(title)]),
                        .p(classes: "ms1 color-gray-40 text-wrapper lh-135", description.widont),
                        .p(classes: "color-gray-65 lh-125 mt", [
                            .text("\(episodes.count) \("Episode".pluralize(episodes.count))"),
                            .span(classes: "ph---", [.raw("&middot;")]),
                            .text(episodes.map { $0.episode }.totalDuration.hoursAndMinutes)
                        ])
                    ])
                ])
            ]),
            .div(classes: "wrapper pt++", [
                .ul(classes: "offset-content", episodes.map { e in
                    .li(classes: "flex justify-center mb++ m+|mb+++", [
                        .div(classes: "width-1 ms1 mr- color-theme-highlight bold lh-110 m-|hide", [.raw("&rarr;")]),
                        .withSession { e.episode.render(.init(wide: true, synopsis: true, watched: e.watched, canWatch: e.episode.canWatch(session: $0), collection: false)) }
                    ])
                })
            ]),
        ], theme: "collection").layout
    }
}

extension Collection {
    struct ViewOptions {
        var episodes: Bool = false
        var whiteBackground: Bool = false
        init(episodes: Bool = false, whiteBackground: Bool = false) {
            self.episodes = episodes
            self.whiteBackground = whiteBackground
        }
    }
    func render(_ options: ViewOptions = ViewOptions()) -> [Node] {
        let figureStyle = "background-color: " + (options.whiteBackground ? "#FCFDFC" : "#F2F4F2")
        let eps: (Session?) -> [Episode] = { self.episodes(for: $0?.user.data) }
        let episodes_: [Node] = options.episodes ? [
            .withSession { session in
                .ul(classes: "mt-",
                    eps(session).map { e in
                        let title = e.title(in: self)
                        return .li(classes: "flex items-baseline justify-between ms-1 line-125", [
                            .span(classes: "nowrap overflow-hidden text-overflow-ellipsis pv- color-gray-45", [
                                .link(to: .episode(e.id, .view(playPosition: nil)), classes: "no-decoration color-inherit hover-underline", [.text(title + (e.released ? "" : " (unreleased)"))])
                                ]),
                            .span(classes: "flex-none pl- pv- color-gray-70", [.text(e.mediaDuration.timeString)])
                        ])
                    }
                )
            }
        ] : []
        return [
            .article(attributes: [:], [
                .link(to: .collection(id), [
                    .figure(attributes: ["class": "mb-", "style": figureStyle], [
                        .hashedImg(classes: "block width-full height-auto", src: artwork)
                    ]),
                ]),
                .div(classes: "flex items-center pt--", [
                    .h3([.link(to: .collection(id), classes: "inline-block lh-110 no-decoration bold color-black hover-under", [.text(title)])])
                ] + (new ? [
                    .span(classes: "flex-none label smallcaps color-white bgcolor-blue nowrap ml-", [.text("New")])
                ] : [])),
                .withSession { session in
                    let e = eps(session)
                    return .p(classes: "ms-1 color-gray-55 lh-125 mt--", [
                        .text("\(e.count) \("Episode".pluralize(e.count))"),
                        .span(classes: "ph---", [.raw("&middot;")]),
                        .text(e.totalDuration.hoursAndMinutes)
                    ])
                }
            ] + episodes_)
        ]
    }
}


