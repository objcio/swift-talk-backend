//
//  Views.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation
import HTML1


enum HeaderContent {
    case node(Node)
    case other(header: String, blurb: String?, extraClasses: Class)
    case link(header: String, backlink: Route, label: String)
    
    var asNode: [Node] {
        switch self {
        case let .node(n):
            return [n]
        case let .other(header: text, blurb: blurb, extraClasses: extraClasses):
            let classes = "color-white bold" + extraClasses + (blurb == nil ? "pb" : "")
            return [
                .h1(class: classes, [.text(text)]), // todo add pb class where blurb = nil
            ] + (blurb == nil ? [] : [
                .div(class: "mt--", [
                    .p(class: "ms2 color-darken-50 lh-110 mw7", [.text(blurb!)])
                ])
        	])
        case let .link(header, backlink, label):
            return [
                .link(to: backlink, class: "ms1 inline-block no-decoration lh-100 pb- color-white opacity-70 hover-underline", [.text(label)]),
                .h1(class: "color-white bold ms4", [.text(header)])
            ]
        }
    }
}

func pageHeader(_ content: HeaderContent, extraClasses: Class? = nil) -> Node {
    return .header(class: "bgcolor-blue pattern-shade" + (extraClasses ?? ""), [
        .div(class: "container", content.asNode)
    ])
}

func errorView(_ message: String) -> Node {
    return LayoutConfig(pageTitle: "Error", contents: [
        .div(class: "container", [
            .text(message)
        ])
    ]).layoutForCheckout
}

