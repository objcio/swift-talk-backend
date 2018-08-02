//
//  Views.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation

struct LayoutConfig {
    var pageTitle: String
    var contents: Node
    var theme: String
    
    init(pageTitle: String = "objc.io", contents: Node, theme: String = "default") {
        self.pageTitle = pageTitle
        self.contents = contents
        self.theme = theme
    }
}

let navigationItems: [(MyRoute, String)] = [
    (.home, "Swift Talk"), // todo
    (.books, "Books"),
    (.issues, "Issues")
]

extension LayoutConfig {
    var layout: Node {
        return .html(attributes: ["lang": "en"], [
            .head([
                .meta(attributes: ["charset": "utf-8"]),
                .meta(attributes: ["http-equiv": "X-UA-Compatible", "content": "IE=edge"]),
                .meta(attributes: ["name": "viewport", "content": "'width=device-width, initial-scale=1, user-scalable=no'"]),
                .title(pageTitle),
                // todo rss+atom links
                .stylesheet(href: "/assets/stylesheets/application.css"),
                // todo google analytics
                ]),
            .body(attributes: ["theme": "theme-" + theme], [ // todo theming classes?
                .header(attributes: ["class": "bgcolor-white"], [
                    .div(class: "height-3 flex scroller js-scroller js-scroller-container", [
                        .div(class: "container-h flex-grow flex", [
                            .link(to: .home,
                                Node.h1("objc.io") // todo class
                            , attributes: ["class": "flex-none outline-none mr++ flex"]),
        					.nav(attributes: ["class": "flex flex-grow"], [
                                .ul(attributes: ["class": "flex flex-auto"], navigationItems.map { l in
                                    .link(to: l.0, Node.span(l.1), attributes: [
                                        "class": "flex items-center fz-nav color-gray-30 color-theme-nav hover-color-theme-highlight no-decoration"
                                    ])
                                })
                            ])
                        ])
                    ])
                ])
            ])
        ])
    }

}

struct Episode: Codable {
    var collection: String?
    var created_at: Int
    var furthest_watched: Double?
    var id: String
    var media_duration: Double?
    var media_url: URL?
    var name: String?
    var number: Int
    var play_position: Double?
    var poster_url: URL?
    var released_at: Int?
    var sample: Bool
    var sample_duration: Double?
    var season: Int
    var small_poster_url: URL?
    var subscription_only: Bool
    var synopsis: String
    var title: String
    var updated_at: Int
    var url: URL?
}
