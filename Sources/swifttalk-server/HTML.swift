//
//  HTML.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation

import Foundation

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
    
    init(name: String, block: Bool = true, attributes: [String:String] = [:], children: [Node] = []) {
        self.name = name
        self.attributes = attributes
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

protocol ToElements {
    var elements: [Node] { get }
}

extension Node: ToElements {
    var elements: [Node] { return [self] }
}

extension Array: ToElements where Element == Node {
    var elements: [Element] {
        return self
    }
}

extension String: ToElements {
    var elements: [Node] { return [.text(self)] } // todo escape
}

extension Node {
    static func html(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "html", attributes: attributes, children: children))
    }
    
    static func meta(attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "meta", attributes: attributes, children: []))
    }
    
    static func body(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "body", attributes: attributes, children: children))
    }
    
    static func p(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "p", attributes: attributes, children: children))
    }
    
    static func head(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "head", attributes: attributes, children: children))
    }
    
    static func header(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "header", attributes: attributes, children: children))
    }
    
    static func title(_ text: ToElements) -> Node {
        return .node(El(name: "title", block: false, children: text.elements))
    }

    static func span(attributes: [String:String] = [:], _ text: ToElements) -> Node {
        return .node(El(name: "span", block: false, attributes: attributes, children: text.elements))
    }

    static func h1(_ title: ToElements, attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "h1", block: false, attributes: attributes, children: title.elements))
    }
    
    static func h2(_ title: ToElements, attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "h2", block: false, attributes: attributes, children: title.elements))
    }
    
    static func h3(_ title: ToElements, attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "h3", block: false, attributes: attributes, children: title.elements))
    }

    static func div(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "div", attributes: attributes, children: children))
    }
    
    static func div(class c: String, _ children: [Node] = []) -> Node {
        let attributes = ["class": c]
        return .node(El(name: "div", attributes: attributes, children: children))
    }
    
    static func nav(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "nav", attributes: attributes, children: children))
    }
    
    static func ul(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "ul", attributes: attributes, children: children))
    }
    
    static func li(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "li", attributes: attributes, children: children))
    }
    
    static func main(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "main", attributes: attributes, children: children))
    }
    
    static func section(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "section", attributes: attributes, children: children))
    }
    
    static func article(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "article", attributes: attributes, children: children))
    }
    
    static func stylesheet(media: String = "all", href: String) -> Node {
        let attributes = [
            "rel": "stylesheet",
            "href": href,
            "media": media
        ]
        return .node(El(name: "link", attributes: attributes, children: []))
    }
    
    static func a(attributes: [String:String] = [:], _ title: ToElements, href: String) -> Node {
        assert(attributes["href"] == nil)
        var att = attributes
        att["href"] = href
        return .node(El(name: "a", block: false, attributes: att, children: title.elements))
    }
}

extension Node: ExpressibleByStringLiteral {
    init(stringLiteral: String) {
        self = .text(stringLiteral)
    }
}

