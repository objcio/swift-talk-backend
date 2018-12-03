//
//  RSS.swift
//  Bits
//
//  Created by Chris Eidhof on 03.12.18.
//

import Foundation

fileprivate let formatter: DateFormatter = {
    let d = DateFormatter()
    d.locale = Locale(identifier: "en_US_POSIX")
    d.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
    return d
}()

extension Swift.Collection where Element == Episode {
    var rssView: ANode<()> {
        typealias X = ANode<()>
        return .xml("rss", attributes: ["version": "2.0", "xmlns:atom": "http://www.w3.org/2005/Atom"], [
            .xml("channel",
                 [
                .xml("title", [.text("objc.io")]),
                .xml("description", [.text("objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development.")]),
                .xml("link", [.text(env.baseURL.absoluteString)]),
                .xml("atom:link", attributes: [
                    "href": rssURL,
                    "rel": "self",
                    "type": "application/rss+xml"
                ]),
                .xml("language", [.text("en")]),
                ] +
                map { (item: Episode) -> ANode<()> in
                    let link = Route.episode(item.id, playPosition: nil).url.absoluteString
                return .xml("item", [
                    .xml("guid", [.text(link)]),
                    .xml("title", [.text(item.title)]),
                    .xml("pubDate", [.text(formatter.string(from: item.release_at.date!))]),
                    .xml("link", [.text(link)]),
                    .xml("description", [.text(item.synopsis)])
                ])
                })
        ])
    }
}
