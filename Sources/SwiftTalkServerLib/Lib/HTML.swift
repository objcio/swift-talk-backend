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
        var result = ""
        result.reserveCapacity(count)
        return unicodeScalars.reduce(into: result, { $0.append($1.escapingIfNeeded) })
    }
    
    var escapeForAttributeValue: String {
        return self.replacingOccurrences(of: "\"", with: "&quot;")
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

enum ANode<I> {
    case none
    case node(El<I>)
    case withInput((I) -> ANode<I>)
    case text(String)
    case raw(String)
}

struct El<I> {
    var name: String
    var attributes: [String:String]
    var block: Bool
    var children: [ANode<I>]
    
    init(name: String, block: Bool = true, classes: Class? = nil, attributes: [String:String] = [:], children: [ANode<I>] = []) {
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
            "\(k)=\"\(v.escapeForAttributeValue)\""
            }.joined(separator: " ")

    }
}

extension El {
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
    
    func ast(input: I) -> El<()> {
        return El<()>(name: name, block: block, attributes: attributes, children: children.map { $0.ast(input: input) })
    }
}
extension ANode {
    func render(input: I, encodeText: (String) -> String = { $0.addingUnicodeEntities }) -> String {
        switch self {
        case .none: return ""
        case .text(let s): return encodeText(s)
        case .raw(let s): return s
        case .withInput(let f): return f(input).render(input: input, encodeText: encodeText)
        case .node(let n): return n.render(input: input, encodeText: encodeText)
        }
    }
    
    func ast(input: I) -> ANode<()> {
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
    
    func htmlDocument(input: I) -> String {
        return ["<!DOCTYPE html>", render(input: input)].joined(separator: "\n")
    }
}

extension ANode {
    static func html(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "html", classes: classes, attributes: attributes, children: children))
    }
    
    static func meta(classes: Class? = nil, attributes: [String:String] = [:]) -> ANode {
        return .node(El(name: "meta", block: false, attributes: attributes, children: []))
    }
    
    static func body(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "body", classes: classes, attributes: attributes, children: children))
    }
    
    static func p(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode]) -> ANode {
        return .node(El(name: "p", classes: classes, attributes: attributes, children: children))
    }
    
    static func head(attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "head", attributes: attributes, children: children))
    }
    
    static func header(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "header", classes: classes, attributes: attributes, children: children))
    }
    
    static func title(_ text: String) -> ANode {
        return .node(El(name: "title", block: false, children: [.text(text)]))
    }

    static var br: ANode {
        return .node(El(name: "br", block: false))
    }
    
    static func span(classes: Class? = nil, attributes: [String:String] = [:], _ text: [ANode]) -> ANode {
        return .node(El(name: "span", block: false, classes: classes, attributes: attributes, children: text))
    }

    static func strong(classes: Class? = nil, attributes: [String:String] = [:], _ text: [ANode]) -> ANode {
        return .node(El(name: "strong", block: false, classes: classes, attributes: attributes, children: text))
    }

    static func h1(classes: Class? = nil, attributes: [String:String] = [:], _ title: [ANode]) -> ANode {
        return .node(El(name: "h1", block: false, classes: classes, attributes: attributes, children: title))
    }
    
    static func h2(classes: Class? = nil, attributes: [String:String] = [:], _ title: [ANode]) -> ANode {
        return .node(El(name: "h2", block: false, classes: classes, attributes: attributes, children: title))
    }
    
    static func h3(classes: Class? = nil, attributes: [String:String] = [:], _ title: [ANode]) -> ANode {
        return .node(El(name: "h3", block: false, classes: classes, attributes: attributes, children: title))
    }
    
    static func h4(classes: Class? = nil, attributes: [String:String] = [:], _ title: [ANode]) -> ANode {
        return .node(El(name: "h4", block: false, classes: classes, attributes: attributes, children: title))
    }
    
    static func img(src: String, alt: String = "", classes: Class? = nil, attributes: [String:String] = [:]) -> ANode {
        var a = attributes
        a["src"] = src
        a["alt"] = alt
        return .node(El(name: "img", block: false, classes: classes, attributes: a, children: []))
    }
    
    static func i(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "i", block: true, classes: classes, attributes: attributes, children: children))
    }
    
    static func div(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "div", classes: classes, attributes: attributes, children: children))
    }
    
    static func fieldset(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "fieldset", classes: classes, attributes: attributes, children: children))
    }
    
    static func label(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "label", classes: classes, attributes: attributes, children: children))
    }
    
    static func table(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "table", classes: classes, attributes: attributes, children: children))
    }
    
    static func thead(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "thead", classes: classes, attributes: attributes, children: children))
    }
    
    static func tbody(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "tbody", classes: classes, attributes: attributes, children: children))
    }
    
    static func tr(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "tr", classes: classes, attributes: attributes, children: children))
    }
    
    static func td(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "td", classes: classes, attributes: attributes, children: children))
    }
    
    static func th(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "th", classes: classes, attributes: attributes, children: children))
    }
    
    static func input(classes: Class? = nil, name: String, id: String? = nil, type: String = "text",  attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        var a = attributes
        a["type"] = type
        a["name"] = name
        a["id"] = id ?? name
        a["type"] = type
        if type == "number" {
            a["inputmode"] = "numeric"
            a["pattern"] = "[0-9]*"
        }
        return .node(El(name: "input", classes: classes, attributes: a, children: children))
    }
    
    static func textArea(classes: Class? = nil, name: String, id: String? = nil, value: String? = nil, placeHolder: String? = nil, rows: Int? = nil, cols: Int? = nil,  attributes: [String:String] = [:]) -> ANode {
        var a = attributes
        a["name"] = name
        a["id"] = id ?? name
        if let r = rows { a["rows"] = "\(r)" }
        if let c = cols { a["cols"] = "\(c)" }
        if let p = placeHolder { a["placeholder"] = p }
        return .node(El(name: "textarea", classes: classes, attributes: a, children: [.text(value ?? "")]))
    }

    static func form(classes: Class? = nil, action: String, acceptCharset: String = "UTF-8", method: HTTPMethod = .post, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        var a = attributes
        a["action"] = action
        a["accept-charset"] = acceptCharset
        a["method"] = method.rawValue
        return .node(El(name: "form", classes: classes, attributes: a, children: children))
    }
    
    static func aside(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "div", classes: classes, attributes: attributes, children: children))
    }
    
    static func iframe(_ source: URL, attributes: [String:String] = [:]) -> ANode {
        var attrs = attributes
        attrs["src"] = source.absoluteString
        return .node(El(name: "iframe", attributes: attrs))
    }
        
    static func video(classes: Class? = nil, attributes: [String:String] = [:], _ source: URL, sourceType: String) -> ANode {
        return .node(El(name: "video", classes: classes, attributes: attributes, children: [
            .node(El(name: "source", attributes: [
                "src": source.absoluteString,
                "type": sourceType
            ]))
        ]))
    }
    
    static func nav(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "nav", classes: classes, attributes: attributes, children: children))
    }
    
    static func ul(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "ul", classes: classes, attributes: attributes, children: children))
    }
    
    static func dl(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "dl", classes: classes, attributes: attributes, children: children))
    }
    
    static func ol(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "ol", classes: classes, attributes: attributes, children: children))
    }
    
    static func li(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "li", classes: classes, attributes: attributes, children: children))
    }
    
    static func dt(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "dt", classes: classes, attributes: attributes, children: children))
    }
    
    static func dd(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "dd", classes: classes, attributes: attributes, children: children))
    }
    
    static func button(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "button", classes: classes, attributes: attributes, children: children))
    }
    
    static func main(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "main", classes: classes, attributes: attributes, children: children))
    }
    
    static func section(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "section", classes: classes, attributes: attributes, children: children))
    }
    
    static func article(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "article", classes: classes, attributes: attributes, children: children))
    }
    
    static func figure(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "figure", classes: classes, attributes: attributes, children: children))
    }
    
    static func footer(classes: Class? = nil, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        return .node(El(name: "footer", classes: classes, attributes: attributes, children: children))
    }

    static func script(src: String) -> ANode {
        return .node(El(name: "script", attributes: [
            "src": src
		], children: []))
    }

    static func script(code: String) -> ANode {
        return .node(El(name: "script", children: [ANode.raw(code)]))
    }
    
    static func xml(_ name: String, attributes: [String:String] = [:], _ children: [ANode] = []) -> ANode {
        let block: Bool
        if children.isEmpty {
            block = false
        } else if children.count == 1, case .text = children[0] {
            block = false
        } else {
            block = true
        }
        return .node(El(name: name, block: block, attributes: attributes, children: children))
    }
    
    static func stylesheet(media: String = "all", href: String) -> Node {
        let attributes = [
            "rel": "stylesheet",
            "href": href,
            "media": media
        ]
        return .node(El(name: "link", attributes: attributes, children: []))
    }

        
    static func a(classes: Class? = nil, attributes: [String:String] = [:], _ title: [ANode], href: String) -> ANode {
        assert(attributes["href"] == nil)
        var att = attributes
        att["href"] = href
        return .node(El(name: "a", block: false, classes: classes, attributes: att, children: title))
    }
}

extension ANode: ExpressibleByStringLiteral {
    init(stringLiteral: String) {
        self = .text(stringLiteral)
    }
}

extension ANode where I == () {
    var xmlDocument: String {
        return ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", render(input: (), encodeText: { $0.xmlString })].joined(separator: "\n")
    }
}

fileprivate extension String {
    var xmlString: String {
        var result = ""
        result.reserveCapacity(count)
        for c in self {
            switch c {
            case "&": result.append("&amp;")
            case "\"": result.append("&quot;")
            case "'": result.append("&apos;")
            case "<": result.append("&lt;")
            case ">": result.append("&gt;")
            default: result.append(c)
            }
        }
        return result
    }
}

extension El where I == () {
    // todo: we might want to check for forms as well
    func linkTargets() -> [String] {
        guard name == "a", let href = attributes["href"] else { return children.flatMap { $0.linkTargets() } }
        return [href]
    }
    
    func forms() -> [(action: String, inputs: [(String,String)])] {
        return children.flatMap { $0.forms() }
    }
    
    func inputs() -> [(String,String)] {
        return children.flatMap { $0.inputs() }
    }
}

extension ANode where I == () {
    // Searches for a's and forms
    func linkTargets() -> [String] {
        switch self {
        case .none:
            return []
        case let .node(n):
            return n.linkTargets()
        case let .withInput(f):
            return f(()).linkTargets()
        case .text:
            return []
        case .raw(_):
            return []
        }
    }
    
    func forms() -> [(action: String, inputs: [(String,String)])] {
        switch self {
        case .none:
            return []
        case let .node(n) where n.name == "form":
            guard let a = n.attributes["action"] else { fatalError() }
            return [(action: a, inputs: n.inputs())] // todo a.inputs
        case .node(let n): return n.forms()
        case let .withInput(f):
            return f(()).forms()
        case .text:
            return []
        case .raw(_):
            return []
        }
    }
    
    func inputs() -> [(String,String)] {
        switch self {
        case .none:
            return []
        case let .node(n) where n.name == "input":
            return [(n.attributes["name"] ?? "", n.attributes["value"] ?? "")]
        case .node(let n):
            return n.inputs()
        case let .withInput(f):
            return f(()).inputs()
        case .text:
            return []
        case .raw(_):
            return []
        }
    }
}

