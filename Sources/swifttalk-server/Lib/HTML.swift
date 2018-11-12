//
//  HTML.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation

// This extension is from HTMLString: https://github.com/alexaubry/HTMLString
extension UnicodeScalar {
    /// Returns the decimal HTML entity for this Unicode scalar.
    public var htmlEscaped: String {
        return "&#" + String(value) + ";"
    }
    
    /// Escapes the scalar only if it needs to be escaped for Unicode pages.
    ///
    /// [Reference](http://wonko.com/post/html-escaping)
    fileprivate var escapingIfNeeded: String {
        switch value {
        case 33, 34, 36, 37, 38, 39, 43, 44, 60, 61, 62, 64, 91, 93, 96, 123, 125: return htmlEscaped
        default: return String(self)
        }
        
    }    
}


extension String {
    var addingUnicodeEntities: String {
        return unicodeScalars.reduce(into: "", { $0.append($1.escapingIfNeeded) })
    }
}

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
    case none
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
            "\(k)=\"\(v.addingUnicodeEntities)\""
            }.joined(separator: " ")

    }
}

extension El {
    func render(encodeText: (String) -> String) -> String {
        let atts: String = attributes.asAttributes
        if children.isEmpty && !block {
            return "<\(name)\(atts) />"
        } else if block {
            return "<\(name)\(atts)>\n" + children.map { $0.render(encodeText: encodeText) }.joined(separator: "\n") + "\n</\(name)>"
        } else {
            return "<\(name)\(atts)>" + children.map { $0.render(encodeText: encodeText) }.joined(separator: "") + "</\(name)>"
        }
    }
}
extension Node {
    func render(encodeText: (String) -> String = { $0.addingUnicodeEntities }) -> String {
        switch self {
        case .none: return ""
        case .text(let s): return encodeText(s)
        case .raw(let s): return s
        case .node(let n): return n.render(encodeText: encodeText)
        }
    }
    
    var htmlDocument: String {
        return ["<!DOCTYPE html>", render()].joined(separator: "\n")
    }
    
    var xmlDocument: String {
        return ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", render(encodeText: { $0.xmlString })].joined(separator: "\n")
    }
}

extension String {
    var xmlString: String {
        // todo this is not efficient!
        var result = self
        result = result.replacingOccurrences(of: "&", with: "&amp") // this has to happen first to prevent double escaping...
        let entities = ["\"": "&quot;", "'": "&apos;", "<": "&lt;", ">": "&gt;"]
        for (key,value) in entities {
            result = result.replacingOccurrences(of: key, with: value)
        }
        return result
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

    static var br: Node {
        return .node(El(name: "br", block: false))
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
    
    static func h4(classes: Class? = nil, _ title: [Node], attributes: [String:String] = [:]) -> Node {
        return .node(El(name: "h4", block: false, classes: classes, attributes: attributes, children: title))
    }
    
    static func img(src: String, alt: String = "", classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        var a = attributes
        a["src"] = src
        a["alt"] = alt
        return .node(El(name: "img", block: false, classes: classes, attributes: a, children: []))

    }
    
    static func i(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "i", block: true, classes: classes, attributes: attributes, children: children))
    }
    
    static func div(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "div", classes: classes, attributes: attributes, children: children))
    }
    
    static func fieldset(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "fieldset", classes: classes, attributes: attributes, children: children))
    }
    
    static func label(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "label", classes: classes, attributes: attributes, children: children))
    }
    
    static func table(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "table", classes: classes, attributes: attributes, children: children))
    }
    
    static func thead(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "thead", classes: classes, attributes: attributes, children: children))
    }
    
    static func tbody(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "tbody", classes: classes, attributes: attributes, children: children))
    }
    
    static func tr(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "tr", classes: classes, attributes: attributes, children: children))
    }
    
    static func td(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "td", classes: classes, attributes: attributes, children: children))
    }
    
    static func th(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "th", classes: classes, attributes: attributes, children: children))
    }
    
    static func input(classes: Class? = nil, name: String, id: String? = nil, type: String = "text",  attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        var a = attributes
        a["type"] = type
        a["name"] = name
        a["id"] = id ?? name
        a["type"] = type
        return .node(El(name: "input", classes: classes, attributes: a, children: children))
    }
    
    static func form(classes: Class? = nil, action: String, acceptCharset: String = "UTF-8", method: HTTPMethod = .post, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        var a = attributes
        a["action"] = action
        a["accept-charset"] = acceptCharset
        a["method"] = method.rawValue
        return .node(El(name: "form", classes: classes, attributes: a, children: children))
    }
    
    static func aside(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "div", classes: classes, attributes: attributes, children: children))
    }
    
    static func iframe(_ source: URL, attributes: [String:String] = [:]) -> Node {
        var attrs = attributes
        attrs["src"] = source.absoluteString
        return .node(El(name: "iframe", attributes: attrs))
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
    
    static func dl(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "dl", classes: classes, attributes: attributes, children: children))
    }
    
    static func ol(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "ol", classes: classes, attributes: attributes, children: children))
    }
    
    static func li(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "li", classes: classes, attributes: attributes, children: children))
    }
    
    static func dt(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "dt", classes: classes, attributes: attributes, children: children))
    }
    
    static func dd(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "dd", classes: classes, attributes: attributes, children: children))
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
    
    static func footer(classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node] = []) -> Node {
        return .node(El(name: "footer", classes: classes, attributes: attributes, children: children))
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

