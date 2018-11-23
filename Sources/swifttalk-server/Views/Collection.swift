//
//  Collection.swift
//  Bits
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation


func index(_ items: [Collection], context: Context) -> Node {
    let lis: [Node] = items.map({ (coll: Collection) -> Node in
        return Node.li(attributes: ["class": "col width-full s+|width-1/2 l+|width-1/3 mb++"], coll.render(.init(episodes: true), context: context))
    })
    return LayoutConfig(context: context, contents: [
        pageHeader(HeaderContent.link(header: "All Collections", backlink: .home, label: "Swift Talk")),
        .div(classes: "container pb0", [
            .h2(attributes: ["class": "bold lh-100 mb+"], [Node.text("\(items.count) Collections")]),
            .ul(attributes: ["class": "cols s+|cols--2n l+|cols--3n"], lis)
            ])
        ]).layout
}

extension Collection {
    func show(context: Context) -> Node {
        let bgImage = "background-image: url('/assets/images/collections/\(title)@4x.png');"
        let eps = episodes(for: context.session?.user.data)
        return LayoutConfig(context: context, contents: [
            Node.div(attributes: ["class": "pattern-illustration overflow-hidden", "style": bgImage], [
                Node.div(classes: "wrapper", [
                    .header(attributes: ["class": "offset-content offset-header pv++ bgcolor-white"], [
                        .p(attributes: ["class": "ms1 color-gray-70 links clearfix"], [
                            .link(to: .home, attributes: ["class": "bold"], [.text("Swift Talk")]),
                            .raw("&#8202;"),
                            .link(to: .collections, attributes: ["class": "opacity: 90"], [.text("Collection")])
                            ]),
                        Node.h2(attributes: ["class": "ms5 bold color-black mt--- lh-110 mb-"], [.text(title)]),
                        Node.p(attributes: ["class": "ms1 color-gray-40 text-wrapper lh-135"], description.widont),
                        Node.p(attributes: ["class": "color-gray-65 lh-125 mt"], [
                            .text(eps.count.pluralize("Episode")),
                            .span(attributes: ["class": "ph---"], [.raw("&middot;")]),
                            .text(eps.totalDuration.hoursAndMinutes)
                            ])
                        ])
                    ])
                ]),
            Node.div(classes: "wrapper pt++", [
                Node.ul(attributes: ["class": "offset-content"], eps.map { e in
                    Node.li(attributes: ["class": "flex justify-center mb++ m+|mb+++"], [
                        Node.div(classes: "width-1 ms1 mr- color-theme-highlight bold lh-110 m-|hide", [.raw("&rarr;")]),
                        e.render(.init(wide: true, synopsis: true, canWatch: e.canWatch(session: context.session), collection: false))
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
    func render(_ options: ViewOptions = ViewOptions(), context: Context) -> [Node] {
        let figureStyle = "background-color: " + (options.whiteBackground ? "#FCFDFC" : "#F2F4F2")
        let eps = episodes(for: context.session?.user.data)
        let episodes_: [Node] = options.episodes ? [
            .ul(attributes: ["class": "mt-"],
                eps.map { e in
                    let title = e.title(in: self)
                    return Node.li(attributes: ["class": "flex items-baseline justify-between ms-1 line-125"], [
                        Node.span(attributes: ["class": "nowrap overflow-hidden text-overflow-ellipsis pv- color-gray-45"], [
                            Node.link(to: .episode(e.id), attributes: ["class": "no-decoration color-inherit hover-underline"], [.text(title + (e.released ? "" : " (unreleased)"))])
                            ]),
                        .span(attributes: ["class": "flex-none pl- pv- color-gray-70"], [.text(e.media_duration.timeString)])
                        ])
                }
            )
            ] : []
        return [
            Node.article(attributes: [:], [
                Node.link(to: .collection(id), [
                    Node.figure(attributes: ["class": "mb-", "style": figureStyle], [
                        Node.hashedImg(src: artwork, attributes: ["class": "block width-full height-auto"])
                        ]),
                    ]),
                Node.div(classes: "flex items-center pt--", [
                    Node.h3([Node.link(to: .collection(id), attributes: ["class": "inline-block lh-110 no-decoration bold color-black hover-under"], [Node.text(title)])])
                ] + (new ? [
                    Node.span(attributes: ["class": "flex-none label smallcaps color-white bgcolor-blue nowrap ml-"], [Node.text("New")])
                ] : [])),
                Node.p(attributes: ["class": "ms-1 color-gray-55 lh-125 mt--"], [
                    .text(eps.count.pluralize("Episode")),
                    .span(attributes: ["class": "ph---"], [Node.raw("&middot;")]),
                    .text(eps.totalDuration.hoursAndMinutes)
                ] as [Node])
            ] + episodes_)
        ]
    }
}


