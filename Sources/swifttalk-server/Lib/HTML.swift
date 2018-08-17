//
//  HTML.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation

struct Class: ExpressibleByStringLiteral {
    var classes: String
    init(stringLiteral string: String) {
        self.classes = string
    }
    
    static func +(lhs: Class, rhs: Class) -> Class {
        return Class(stringLiteral: lhs.classes + " " + rhs.classes)
    }
}

enum Node {
    case node(El)
    case text(String)
    case raw(String)
}

struct El {
    var name: String
    var attributes: [String:String]
    var block: Bool
    var children: [Node]
    
    init(name: String, block: Bool = true, classes: Class? = nil, attributes: [String:String] = [:], children: [Node] = []) {
        self.name = name
        self.attributes = attributes
        if let c = classes {
            self.attributes["class", default: ""] += " " + c.classes
        }
        self.children = children
        self.block = block
    }
}

extension Dictionary where Key == String, Value == String {
    var asAttributes: String {
        return isEmpty ? "" : " " + map { (k,v) in
            "\(k)=\"\(v)\"" // todo escape
            }.joined(separator: " ")

    }
}

extension El {
    var render: String {
        let atts: String = attributes.asAttributes
        if children.isEmpty && !block {
            return "<\(name)\(atts) />"
        } else if block {
            return "<\(name)\(atts)>\n" + children.map { $0.render }.joined(separator: "\n") + "\n</\(name)>"
        } else {
            return "<\(name)\(atts)>" + children.map { $0.render }.joined(separator: "") + "</\(name)>"
        }
    }
}
extension Node {
    var render: String {
        switch self {
        case .text(let s): return s // todo escape
        case .raw(let s): return s
        case .node(let n): return n.render
        }
    }
    
    var document: String {
        return ["<!DOCTYPE html>", render].joined(separator: "\n")
    }
}

extension Node {
    static func html(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "html", classes: classes, attributes: attributes, children: children))
    }
    
    static func meta(classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "meta", block: false, attributes: attributes, children: []))
    }
    
    static func body(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "body", classes: classes, attributes: attributes, children: children))
    }
    
    static func p(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return .node(El(name: "p", classes: classes, attributes: attributes, children: children))
    }
    
    static func head(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "head", attributes: attributes, children: children))
    }
    
    static func header(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "header", classes: classes, attributes: attributes, children: children))
    }
    
    static func title(_ text: String) -> Node {
        return .node(El(name: "title", block: false, children: [.text(text)]))
    }

    static func span(classes: Class? = nil, attributes: [String:String] = [:], _ text: [Node]) -> Node {
        return .node(El(name: "span", block: false, classes: classes, attributes: attributes, children: text))
    }

    // todo arg order
    static func h1(classes: Class? = nil, _ title: [Node], attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "h1", block: false, classes: classes, attributes: attributes, children: title))
    }
    
    static func h2(classes: Class? = nil, _ title: [Node], attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "h2", block: false, classes: classes, attributes: attributes, children: title))
    }
    
    static func h3(classes: Class? = nil, _ title: [Node], attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "h3", block: false, classes: classes, attributes: attributes, children: title))
    }
    
    static func img(src: String, alt: String = "", classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        var a = attributes
        a["src"] = src
        a["alt"] = alt
        return .node(El(name: "img", block: false, classes: classes, attributes: a, children: []))
    }

    static func div(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "div", classes: classes, attributes: attributes, children: children))
    }
    
    static func aside(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "div", classes: classes, attributes: attributes, children: children))
    }
        
    static func video(classes: Class? = nil, attributes: [String:String] = [:], _ source: URL, sourceType: String) -> Node {
        return .node(El(name: "video", classes: classes, attributes: attributes, children: [
            .node(El(name: "source", attributes: [
                "src": source.absoluteString,
                "type": sourceType
            ]))
        ]))
    }
    
    static func nav(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "nav", classes: classes, attributes: attributes, children: children))
    }
    
    static func ul(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "ul", classes: classes, attributes: attributes, children: children))
    }
    
    static func ol(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "ol", classes: classes, attributes: attributes, children: children))
    }
    
    static func li(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "li", classes: classes, attributes: attributes, children: children))
    }
    
    static func button(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "button", classes: classes, attributes: attributes, children: children))
    }
    
    static func main(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "main", classes: classes, attributes: attributes, children: children))
    }
    
    static func section(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "section", classes: classes, attributes: attributes, children: children))
    }
    
    static func article(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "article", classes: classes, attributes: attributes, children: children))
    }
    
    static func figure(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "figure", classes: classes, attributes: attributes, children: children))
    }


    static func script(src: String) -> Node {
        return .node(El(name: "script", attributes: [
            "src": src
		], children: []))
    }
    
    static func stylesheet(media: String = "all", href: String) -> Node {
        let attributes = [
            "rel": "stylesheet",
            "href": href,
            "media": media
        ]
        return .node(El(name: "link", attributes: attributes, children: []))
    }
    
    static func a(classes: Class? = nil, attributes: [String:String] = [:], _ title: [Node], href: String) -> Node {
        assert(attributes["href"] == nil)
        var att = attributes
        att["href"] = href
        return .node(El(name: "a", block: false, classes: classes, attributes: att, children: title))
    }
}

extension Node: ExpressibleByStringLiteral {
    init(stringLiteral: String) {
        self = .text(stringLiteral)
    }
}

