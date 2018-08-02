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

let test = """
<nav class="flex-none self-center border-left border-1 border-color-gray-85 flex ml+">
<ul class="flex items-stretch">
<li class="flex ml+">
<a class="flex items-center fz-nav color-gray-30 color-theme-nav hover-color-theme-highlight no-decoration" href="/users/auth/github">Log in</a>
</li>

<li class="flex items-center ml+">
<a class="button button--tight button--themed fz-nav" href="/subscribe">Subscribe</a>
</li>
</ul>
</nav>
"""

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
            .body(attributes: ["class": "theme-" + theme], [ // todo theming classes?
                .header(attributes: ["class": "bgcolor-white"], [
                    .div(class: "height-3 flex scroller js-scroller js-scroller-container", [
                        .div(class: "container-h flex-grow flex", [
                            .link(to: .home, [
        						.inlineSvg(path: "images/logo.svg", attributes: ["class": "block logo logo--themed height-auto"]), // todo scaling parameter?
        						.h1("objc.io", attributes: ["class":"visuallyhidden"]) // todo class
        					] as [Node]
                            , attributes: ["class": "flex-none outline-none mr++ flex"]),
        					.nav(attributes: ["class": "flex flex-grow"], [
                                .ul(attributes: ["class": "flex flex-auto"], navigationItems.map { l in
                                    .li(attributes: ["class": "flex mr+"], [
                                        .link(to: l.0, Node.span(l.1), attributes: [
                                            "class": "flex items-center fz-nav color-gray-30 color-theme-nav hover-color-theme-highlight no-decoration"
                                        ])
                                    ])
                                }) // todo: search
                            ]),
                            .raw(test)
                        ])
                    ])
                ]),
                .main(contents.elements) // todo sidenav
                // todo footer
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
