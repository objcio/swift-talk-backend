//
//  Views.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation

struct LayoutConfig {
    var pageTitle: String = "objc.io"
    var contents: Node
    var theme: String = "default"
}

extension LayoutConfig {
    var layout: Node {
        return .html(attributes: ["lang": "en"], [
            .head([
                .meta(attributes: ["charset": "utf-8"]),
                .meta(attributes: ["http-equiv": "X-UA-Compatible", "content": "IE=edge"]),
                .meta(attributes: ["name": "viewport", "content": "'width=device-width, initial-scale=1, user-scalable=no'"]),
                .title(pageTitle),
                // todo rss+atom links
                .stylesheet(href: "/static/assets/stylesheets/application.css"),
                // todo google analytics
                ]),
            .body(attributes: ["theme": "theme-" + theme], [ // todo theming classes?
                .header(attributes: ["class": "bgcolor-white"], [
                    .div(class: "height-3 flex scroller js-scroller js-scroller-container", [
                        .div(class: "container-h flex-grow flex", [
                            // todo link to header
                            
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
