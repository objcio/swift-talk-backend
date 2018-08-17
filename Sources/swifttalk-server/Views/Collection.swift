//
//  Collection.swift
//  Bits
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation


func index(_ items: [Collection], session: Session?) -> Node {
    let lis: [Node] = items.map({ (coll: Collection) -> Node in
        return Node.li(attributes: ["class": "col width-full s+|width-1/2 l+|width-1/3 mb++"], coll.render(.init(episodes: true)))
    })
    return LayoutConfig(session: session, contents: [
        pageHeader(HeaderContent.link(header: "All Collections", backlink: .home, label: "Swift Talk")),
        .div(classes: "container pb0", [
            .h2([Node.text("\(items.count) Collections")], attributes: ["class": "bold lh-100 mb+"]),
            .ul(attributes: ["class": "cols s+|cols--2n l+|cols--3n"], lis)
            ])
        ]).layout
}

extension Collection {
    func show(session: Session?) -> Node {
        let bgImage = "background-image: url('/assets/images/collections/\(title)@4x.png');"
        return LayoutConfig(session: session, contents: [
            Node.div(attributes: ["class": "pattern-illustration overflow-hidden", "style": bgImage], [
                Node.div(classes: "wrapper", [
                    .header(attributes: ["class": "offset-content offset-header pv++ bgcolor-white"], [
                        .p(attributes: ["class": "ms1 color-gray-70 links clearfix"], [
                            .link(to: .home, [.text("Swift Talk")], attributes: ["class": "bold"]),
                            .raw("&#8202;"),
                            .link(to: .collections, [.text("Collection")], attributes: ["class": "opacity: 90"])
                            ]),
                        Node.h2([.text(title)], attributes: ["class": "ms5 bold color-black mt--- lh-110 mb-"]),
                        Node.p(attributes: ["class": "ms1 color-gray-40 text-wrapper lh-135"], description.widont),
                        Node.p(attributes: ["class": "color-gray-65 lh-125 mt"], [
                            .text(episodes.released.count.pluralize("Episode")),
                            .span(attributes: ["class": "ph---"], [.raw("&middot;")]),
                            .text(total_duration.hoursAndMinutes)
                            ])
                        ])
                    ])
                ]),
            Node.div(classes: "wrapper pt++", [
                Node.ul(attributes: ["class": "offset-content"], episodes.released.map { e in
                    Node.li(attributes: ["class": "flex justify-center mb++ m+|mb+++"], [
                        Node.div(classes: "width-1 ms1 mr- color-theme-highlight bold lh-110 m-|hide", [.raw("&rarr;")]),
                        e.render(.init(wide: true, synopsis: true, canWatch: session.premiumAccess || !e.subscription_only, collection: false))
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
        let episodes_: [Node] = options.episodes ? [
            .ul(attributes: ["class": "mt-"],
                episodes.filter { $0.released }.map { e in
                    let title = e.title(in: self)
                    return Node.li(attributes: ["class": "flex items-baseline justify-between ms-1 line-125"], [
                        Node.span(attributes: ["class": "nowrap overflow-hidden text-overflow-ellipsis pv- color-gray-45"], [
                            Node.link(to: .episode(e.slug), [.text(title)], attributes: ["class": "no-decoration color-inherit hover-underline"])
                            ]),
                        .span(attributes: ["class": "flex-none pl- pv- color-gray-70"], [.text(e.media_duration?.timeString ?? "")])
                        ])
                }
            )
            ] : []
        return [
            Node.article(attributes: [:], [
                Node.link(to: .collection(slug), [
                    Node.figure(attributes: ["class": "mb-", "style": figureStyle], [
                        Node.img(src: artwork, attributes: ["class": "block width-full height-auto"])
                        ]),
                    ]),
                Node.div(classes: "flex items-center pt--", [
                    Node.h3([Node.link(to: .collection(slug), [Node.text(title)], attributes: ["class": "inline-block lh-110 no-decoration bold color-black hover-under"])])
                    ] + (new ? [
                        Node.span(attributes: ["class": "flex-none label smallcaps color-white bgcolor-blue nowrap ml-"], [Node.text("New")])
                        ] : [])),
                Node.p(attributes: ["class": "ms-1 color-gray-55 lh-125 mt--"], [
                    .text(episodes.count.pluralize("Episode")),
                    .span(attributes: ["class": "ph---"], [Node.raw("&middot;")]),
                    .text(total_duration.hoursAndMinutes)
                    ] as [Node])
                ] + episodes_)
        ]
    }
}


