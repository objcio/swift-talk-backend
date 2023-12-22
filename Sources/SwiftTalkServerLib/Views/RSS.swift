//
//  RSS.swift
//  Bits
//
//  Created by Chris Eidhof on 03.12.18.
//

import Foundation
import HTML1


fileprivate let formatter: DateFormatter = {
    let d = DateFormatter()
    d.locale = Locale(identifier: "en_US_POSIX")
    d.dateFormat = "E, d MMM yyyy HH:mm:ss Z"
    return d
}()

extension Swift.Collection where Element == Episode {
    var rssView: HTML1.Node<()> {
        typealias X = HTML1.Node<()>
        return .xml(name: "rss", attributes: ["version": "2.0", "xmlns:atom": "http://www.w3.org/2005/Atom"], [
            .xml(name: "channel",
                 [
                .xml(name: "title", ["objc.io"]),
                .xml(name: "description", ["objc.io publishes books, videos, and articles on advanced techniques for iOS and macOS development."]),
                .xml(name: "link", [.text(env.baseURL.absoluteString)]),
                .xml(name: "atom:link", attributes: [
                    "href": rssURL,
                    "rel": "self",
                    "type": "application/rss+xml"
                ]),
                .xml(name: "language", ["en"]),
                ] +
                map { (item: Episode) -> HTML1.Node<()> in
                    let link = Route.episode(item.id, .view(playPosition: nil)).url.absoluteString
                return .xml(name: "item", [
                    .xml(name: "guid", [.text(link)]),
                    .xml(name: "title", [.text(item.title)]),
                    .xml(name: "pubDate", [.text(formatter.string(from: item.releaseAt))]),
                    .xml(name: "link", [.text(link)]),
                    .xml(name: "description", [.text(item.synopsis)])
                ])
            })
        ])
    }
}
