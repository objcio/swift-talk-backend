//
//  HTML.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation
import Base


public enum Node<I> {
    case none
    case node(Element<I>)
    case withInput((I) -> Node<I>)
    case text(String)
    case raw(String)
}

public struct Element<I> {
    var name: String
    var attributes: [String:String]
    var block: Bool
    public var children: [Node<I>]
    
    public init(name: String, block: Bool = true, classes: Class? = nil, attributes: [String:String] = [:], children: [Node<I>] = []) {
        self.name = name
        self.attributes = attributes
        if let c = classes {
            self.attributes["class", default: ""] += " " + c.classes
        }
        self.children = children
        self.block = block
    }
}

public struct Class: ExpressibleByStringLiteral {
    public var classes: String
    public init(stringLiteral string: String) {
        self.classes = string
    }
    
    public static func +(lhs: Class, rhs: Class) -> Class {
        return Class(stringLiteral: lhs.classes + " " + rhs.classes)
    }
}

extension Element {
    func render(input: I, encodeText: (String) -> String) -> String {
        let atts: String = attributes.asAttributes
        if children.isEmpty && !block {
            return "<\(name)\(atts) />"
        } else if block {
            return "<\(name)\(atts)>\n" + children.map { $0.render(input: input, encodeText: encodeText) }.joined(separator: "\n") + "\n</\(name)>"
        } else {
            return "<\(name)\(atts)>" + children.map { $0.render(input: input, encodeText: encodeText) }.joined(separator: "") + "</\(name)>"
        }
    }
    
    public func ast(input: I) -> Element<()> {
        return Element<()>(name: name, block: block, attributes: attributes, children: children.map { $0.ast(input: input) })
    }
}

extension Node {
    func render(input: I, encodeText: (String) -> String = { $0.addingUnicodeEntities }) -> String {
        switch self {
        case .none: return ""
        case .text(let s): return encodeText(s)
        case .raw(let s): return s
        case .withInput(let f): return f(input).render(input: input, encodeText: encodeText)
        case .node(let n): return n.render(input: input, encodeText: encodeText)
        }
    }
    
    public func ast(input: I) -> Node<()> {
        switch self {
        case .none:
            return .none
        case let .node(n):
            return .node(n.ast(input: input))
        case let .withInput(f):
            return f(input).ast(input: input)
        case let .text(t):
            return .text(t)
        case let .raw(r):
            return .raw(r)
        }
    }
    
    public func htmlDocument(input: I) -> String {
        return ["<!DOCTYPE html>", render(input: input)].joined(separator: "\n")
    }
}

extension Node {
    public static func html(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "html", classes: classes, attributes: attributes, children: children))
    }
    
    public static func meta(classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        return .node(Element(name: "meta", block: false, attributes: attributes, children: []))
    }
    
    public static func body(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "body", classes: classes, attributes: attributes, children: children))
    }
    
    public static func p(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return .node(Element(name: "p", classes: classes, attributes: attributes, children: children))
    }
    
    public static func head(attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "head", attributes: attributes, children: children))
    }
    
    public static func header(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "header", classes: classes, attributes: attributes, children: children))
    }
    
    public static func title(_ text: String) -> Node {
        return .node(Element(name: "title", block: false, children: [.text(text)]))
    }

    public static var br: Node {
        return .node(Element(name: "br", block: false))
    }
    
    public static func span(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return .node(Element(name: "span", block: false, classes: classes, attributes: attributes, children: children))
    }

    public static func strong(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return .node(Element(name: "strong", block: false, classes: classes, attributes: attributes, children: children))
    }

    public static func h1(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return .node(Element(name: "h1", block: false, classes: classes, attributes: attributes, children: children))
    }
    
    public static func h2(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return .node(Element(name: "h2", block: false, classes: classes, attributes: attributes, children: children))
    }
    
    public static func h3(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return .node(Element(name: "h3", block: false, classes: classes, attributes: attributes, children: children))
    }
    
    public static func h4(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return .node(Element(name: "h4", block: false, classes: classes, attributes: attributes, children: children))
    }
    
    public static func img(classes: Class? = nil, src: String, alt: String = "", attributes: [String:String] = [:]) -> Node {
        var a = attributes
        a["src"] = src
        a["alt"] = alt
        return .node(Element(name: "img", block: false, classes: classes, attributes: a, children: []))
    }
    
    public static func i(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "i", block: true, classes: classes, attributes: attributes, children: children))
    }
    
    public static func div(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "div", classes: classes, attributes: attributes, children: children))
    }
    
    public static func fieldset(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "fieldset", classes: classes, attributes: attributes, children: children))
    }
    
    public static func label(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "label", classes: classes, attributes: attributes, children: children))
    }
    
    public static func table(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "table", classes: classes, attributes: attributes, children: children))
    }
    
    public static func thead(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "thead", classes: classes, attributes: attributes, children: children))
    }
    
    public static func tbody(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "tbody", classes: classes, attributes: attributes, children: children))
    }
    
    public static func tr(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "tr", classes: classes, attributes: attributes, children: children))
    }
    
    public static func td(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "td", classes: classes, attributes: attributes, children: children))
    }
    
    public static func th(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "th", classes: classes, attributes: attributes, children: children))
    }
    
    public static func input(classes: Class? = nil, name: String, id: String? = nil, type: String = "text",  attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        var a = attributes
        a["type"] = type
        a["name"] = name
        a["id"] = id ?? name
        a["type"] = type
        if type == "number" {
            a["inputmode"] = "numeric"
            a["pattern"] = "[0-9]*"
        }
        return .node(Element(name: "input", classes: classes, attributes: a, children: children))
    }
    
    public static func textArea(classes: Class? = nil, name: String, id: String? = nil, value: String? = nil, placeHolder: String? = nil, rows: Int? = nil, cols: Int? = nil, attributes: [String:String] = [:]) -> Node {
        var a = attributes
        a["name"] = name
        a["id"] = id ?? name
        if let r = rows { a["rows"] = "\(r)" }
        if let c = cols { a["cols"] = "\(c)" }
        if let p = placeHolder { a["placeholder"] = p }
        return .node(Element(name: "textarea", classes: classes, attributes: a, children: [.text(value ?? "")]))
    }

    public static func form(classes: Class? = nil, action: String, acceptCharset: String = "UTF-8", method: HTTPMethod = .post, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        var a = attributes
        a["action"] = action
        a["accept-charset"] = acceptCharset
        a["method"] = method.rawValue
        return .node(Element(name: "form", classes: classes, attributes: a, children: children))
    }
    
    public static func aside(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "div", classes: classes, attributes: attributes, children: children))
    }
    
    public static func iframe(source: URL, attributes: [String:String] = [:]) -> Node {
        var attrs = attributes
        attrs["src"] = source.absoluteString
        return .node(Element(name: "iframe", attributes: attrs))
    }
        
    public static func video(classes: Class? = nil, source: URL, sourceType: String, attributes: [String:String] = [:]) -> Node {
        return .node(Element(name: "video", classes: classes, attributes: attributes, children: [
            .node(Element(name: "source", attributes: [
                "src": source.absoluteString,
                "type": sourceType
            ]))
        ]))
    }
    
    public static func nav(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "nav", classes: classes, attributes: attributes, children: children))
    }
    
    public static func ul(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "ul", classes: classes, attributes: attributes, children: children))
    }
    
    public static func dl(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "dl", classes: classes, attributes: attributes, children: children))
    }
    
    public static func ol(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "ol", classes: classes, attributes: attributes, children: children))
    }
    
    public static func li(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "li", classes: classes, attributes: attributes, children: children))
    }
    
    public static func dt(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "dt", classes: classes, attributes: attributes, children: children))
    }
    
    public static func dd(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "dd", classes: classes, attributes: attributes, children: children))
    }
    
    public static func button(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "button", classes: classes, attributes: attributes, children: children))
    }
    
    public static func main(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "main", classes: classes, attributes: attributes, children: children))
    }
    
    public static func section(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "section", classes: classes, attributes: attributes, children: children))
    }
    
    public static func article(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "article", classes: classes, attributes: attributes, children: children))
    }
    
    public static func figure(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "figure", classes: classes, attributes: attributes, children: children))
    }
    
    public static func footer(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(Element(name: "footer", classes: classes, attributes: attributes, children: children))
    }

    public static func script(src: String) -> Node {
        return .node(Element(name: "script", attributes: [
            "src": src
		], children: []))
    }

    public static func script(code: String) -> Node {
        return .node(Element(name: "script", children: [Node.raw(code)]))
    }
    
    public static func xml(name: String, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        let block: Bool
        if children.isEmpty {
            block = false
        } else if children.count == 1, case .text = children[0] {
            block = false
        } else {
            block = true
        }
        return .node(Element(name: name, block: block, attributes: attributes, children: children))
    }
    
    public static func stylesheet(media: String = "all", href: String) -> Node {
        let attributes = [
            "rel": "stylesheet",
            "href": href,
            "media": media
        ]
        return .node(Element(name: "link", attributes: attributes, children: []))
    }

        
    public static func a(classes: Class? = nil, href: String, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        assert(attributes["href"] == nil)
        var att = attributes
        att["href"] = href
        return .node(Element(name: "a", block: false, classes: classes, attributes: att, children: children))
    }
}

extension Node: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {
        self = .text(stringLiteral)
    }
}

extension Node where I == () {
    public var xmlDocument: String {
        return ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", render(input: (), encodeText: { $0.xmlString })].joined(separator: "\n")
    }
}

