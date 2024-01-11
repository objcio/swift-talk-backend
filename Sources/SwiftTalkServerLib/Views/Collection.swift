//
//  Collection.swift
//  Bits
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import HTML1


func index(_ items: [Collection]) -> Node {
    let lis: [Node] = items.map({ (coll: Collection) -> Node in
        return .li(class: "col width-full s+|width-1/2 l+|width-1/3 mb++", coll.render(.init(episodes: true)))
    })
    return LayoutConfig(pageTitle: "All Collections", contents: [
        pageHeader(HeaderContent.link(header: "All Collections", backlink: .home, label: "Swift Talk")),
        .div(class: "container pb0", [
            .h2(class: "bold lh-100 mb+", ["\(items.count) Collections"]),
            .ul(class: "cols s+|cols--2n l+|cols--3n", lis)
        ])
    ]).layout
}

extension Collection {
    func show(episodes: [EpisodeWithProgress]) -> Node {
        return .withRoute { currentRoute in
            let imageURL = Route.staticFile(path: ["images", "collections", "\(self.title)@4x.png"]).url
            let bgImage = "background-image: url('\(imageURL.path)');"
            let numberOfEpisodes = "\(episodes.count) \("Episode".pluralize(episodes.count))"
            let structuredData = StructuredData(title: "Swift Talk Collection: \(self.title)", description: self.description, url: currentRoute.url, image: imageURL, type: .website)
            return LayoutConfig(pageTitle: self.title.constructTitle, contents: [
                .div(attributes: ["class": "pattern-illustration overflow-hidden", "style": bgImage], [
                    .div(class: "wrapper", [
                        .header(class: "offset-content offset-header pv++ bgcolor-white", [
                            .p(class: "ms1 color-gray-70 links clearfix", [
                                .link(to: .home, class: "bold", ["Swift Talk"]),
                                .raw("&#8202;"),
                                .link(to: .collections, class: "opacity: 90", ["Collection"])
                            ]),
                            .h2(class: "ms5 bold color-black mt--- lh-110 mb-", [.text(self.title)]),
                            .p(class: "ms1 color-gray-40 text-wrapper lh-135", self.description.widont),
                            .p(class: "color-gray-65 lh-125 mt", [
                                .text(numberOfEpisodes),
                                .span(class: "ph---", [.raw("&middot;")]),
                                .text(episodes.map { $0.episode }.totalDuration.hoursAndMinutes)
                            ])
                        ])
                    ])
                ]),
                .div(class: "wrapper pt++", [
                    .ul(class: "offset-content", zip(episodes, 1...).map { e, num in
                        .li(class: "flex justify-center mb++ m+|mb+++", [
                            .div(class: "width-1 ms1 mr- color-theme-highlight bold lh-110 m-|hide", [self.displayChronologically ? "\(num)." : .raw("&rarr;")]),
                            .withSession { e.episode.render(.init(wide: true, synopsis: true, watched: e.watched, canWatch: e.episode.canWatch(session: $0), collection: false)) }
                        ])
                    })
                ]),
            ], structuredData: structuredData).layout
        }
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
                .ul(class: "mt-",
                    eps(session).map { e in
                        let title = e.title(in: self)
                        return .li(class: "flex items-baseline justify-between ms-1 line-125", [
                            .span(class: "nowrap overflow-hidden text-overflow-ellipsis pv- color-gray-45", [
                                .link(to: .episode(e.id, .view(playPosition: nil)), class: "no-decoration color-inherit hover-underline", [.text(title + (e.released ? "" : " (unreleased)"))])
                                ]),
                            .span(class: "flex-none pl- pv- color-gray-70", [.text(e.mediaDuration.timeString)])
                        ])
                    }
                )
            }
        ] : []
        return [
            .article(attributes: [:], [
                .link(to: .collection(id), [
                    .figure(attributes: ["class": "mb-", "style": figureStyle], [
                        .hashedImg(class: "block width-full height-auto", src: artwork)
                    ]),
                ]),
                .div(class: "flex items-center pt--", [
                    .h3([.link(to: .collection(id), class: "inline-block lh-110 no-decoration bold color-black hover-under", [.text(title)])])
                ] + (new ? [
                    .span(class: "flex-none label smallcaps color-white bgcolor-blue nowrap ml-", ["New"])
                ] : [])),
                .withSession { session in
                    let e = eps(session)
                    return .p(class: "ms-1 color-gray-55 lh-125 mt--", [
                        "\(e.count) \("Episode".pluralize(e.count))",
                        .span(class: "ph---", [.raw("&middot;")]),
                        .text(e.totalDuration.hoursAndMinutes)
                    ])
                }
            ] + episodes_)
        ]
    }
}


