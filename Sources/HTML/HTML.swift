//
//  HTML.swift
//  Bits
//
//  Created by Chris Eidhof on 31.07.18.
//

import Foundation
import Base

extension Reader: ElementLike where Result: ElementLike {
    public typealias N = Reader<Value, Result.N>
    public init(_ name: String, block: Bool, class: Class?, attributes: [String : String], children: [Reader<Value, Result.N>]) {
        self = Reader { input in
            let x = children.map { $0.run(input) }
            return Result.init(name: name, block: block, class: `class`, attributes: attributes, children: x)
        }
        
    }
}

extension Reader: ExpressibleByUnicodeScalarLiteral where Result: ExpressibleByUnicodeScalarLiteral {
    public init(unicodeScalarLiteral value: Result.UnicodeScalarLiteralType) {
        self = .const(.init(unicodeScalarLiteral: value))
    }
    
    public typealias UnicodeScalarLiteralType = Result.UnicodeScalarLiteralType
    
    
}

extension Reader: ExpressibleByExtendedGraphemeClusterLiteral where Result: ExpressibleByExtendedGraphemeClusterLiteral {
    public init(extendedGraphemeClusterLiteral value: Result.ExtendedGraphemeClusterLiteralType) {
        self = Reader<Value, Result>.const(.init(extendedGraphemeClusterLiteral: value))
    }
}

extension Reader: ExpressibleByStringLiteral where Result: ExpressibleByStringLiteral {
    public init(stringLiteral value: Result.StringLiteralType) {
        self = Reader<Value, Result>.const(.init(stringLiteral: value))
    }
}

extension Reader: ExpressibleByStringInterpolation where Result: ExpressibleByStringInterpolation, Result.StringLiteralType == String {
//    typealias StringInterpolation = Result.StringInterpolation
    public init(stringInterpolation: Result.StringInterpolation) {
        self = Reader<Value, Result>.const(.init(stringInterpolation: stringInterpolation))
    }
}

extension Reader: NodeLike where Result: NodeLike {
    public typealias Element = Reader<Value, Result.Element>
    public typealias Input = Value
    
    public static func none() -> Reader<Value, Result> {
        return .const(.none())
    }
    public static func raw(_ r: String) -> Reader<Value, Result> {
        return .const(.raw(r))
    }
    public static func text(_ t: String) -> Reader<Value, Result> {
        return .const(.text(t))
    }
    public static func withInput(_ f: @escaping (Value) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { input in
            f(input).run(input)
        }
    }
    public static func node(_ el: Element) -> Reader<Value, Result> {
        return Reader { value in
            Result.node(el.run(value))
        }
    }
}

public protocol ElementLike {
    associatedtype N: NodeLike
    init(_ name: String, block: Bool, class: Class?, attributes: [String:String], children: [N])
}

extension ElementLike {
    public init(name: String, block: Bool = true, class: Class? = nil, attributes: [String:String] = [:], children: [N] = []) {
        self.init(name, block: block, class: `class`, attributes: attributes, children: children)
    }
}

public protocol NodeLike:  ExpressibleByStringInterpolation  {
    typealias StringInterpolation = String.StringInterpolation

    associatedtype Input
    associatedtype Element: ElementLike where Element.N == Self
    static func none() -> Self
    static func node(_ el: Element) -> Self
    static func withInput(_ f: @escaping (Input) -> Self) -> Self
    static func text(_ t: String) -> Self
    static func raw(_ r: String) -> Self
}

//extension NodeLike {
//    public typealias StringInterpolation = String.StringInterpolation
//    init(
//}
//
protocol XMLEncodable: ElementLike, NodeLike {
    static func encodeText(_ string: String) -> String
    init(strings: [String])
    var strings: [String] { get }
}

public struct RenderedHTML: XMLEncodable {
    static func encodeText(_ string: String) -> String {
        return string.addingUnicodeEntities
    }
    
    var strings: [String] = []
    
    public var string: String { return strings.joined(separator: "") }
    init(strings: [String]) { self.strings = strings }
}

public struct RenderedXML: XMLEncodable {
    static func encodeText(_ string: String) -> String {
        return string.xmlString
    }
    
    var strings: [String] = []
    
    public var string: String { return strings.joined(separator: "") }
    init(strings: [String]) { self.strings = strings }
}

extension RenderedXML {
    public var xmlDocument: String {
        return ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", string].joined(separator: "\n")
    }    
}


extension XMLEncodable {
    public init(_ name: String, block: Bool, class: Class?, attributes: [String : String], children: [Self]) {
        let atts: String = attributes.asAttributes
        if children.isEmpty && !block {
            self = .init(strings: ["<\(name)\(atts) />"])
        } else if block {
//            self = .init(string: "<\(name)\(atts)>\n" + children.map { $0.string }.joined(separator: "\n") + "\n</\(name)>")
            self = .init(strings: ["<\(name)\(atts)>\n"] + children.flatMap { $0.strings } + ["\n</\(name)>"]) // todo newlines

        } else {
            self = .init(strings: ["<\(name)\(atts)>"] + children.flatMap { $0.strings } + ["</\(name)>"])
        }
    }
}

extension XMLEncodable {
    public static func none() -> Self {
        return .init(strings: [])
    }
    
    public static func node(_ el: Self) -> Self {
        return el
    }
    
    public static func withInput(_ f: @escaping (()) -> Self) -> Self {
        return f(())
    }
    
    public static func text(_ t: String) -> Self {
        return .init(strings: [Self.encodeText(t)])
    }
    
    public static func raw(_ r: String) -> Self {
        return .init(strings: [r])
    }
}

public enum Node<I> {
    case _none
    case _node(Element<I>)
    case _withInput((I) -> Node<I>)
    case _text(String)
    case _raw(String)
}

extension Node: NodeLike {
    public static func none() -> Node<I> {
        return ._none
    }
 
    public static func node(_ el: Element<I>) -> Node<I> {
        return ._node(el)
    }
 
    public static func withInput(_ f: @escaping (I) -> Node<I>) -> Node<I> {
        return ._withInput(f)
    }
 
    public static func text(_ t: String) -> Node<I> {
        return ._text(t)
    }
 
    public static func raw(_ r: String) -> Node<I> {
        return ._raw(r)
    }
 
    public typealias Input = I
}

public struct Element<I>: ElementLike {
    var name: String
    var attributes: [String:String]
    var block: Bool
    public var children: [Node<I>]
 
    public init(_ name: String, block: Bool = true, class: Class? = nil, attributes: [String:String] = [:], children: [Node<I>] = []) {
        self.name = name
        self.attributes = attributes
        if let c = `class` {
            self.attributes["class", default: ""] += " " + c.class
        }
        self.children = children
        self.block = block
    }
}
 
public struct Class: ExpressibleByStringLiteral {
    public var `class`: String
    public init(stringLiteral string: String) {
        self.class = string
    }
    
    public static func +(lhs: Class, rhs: Class) -> Class {
        return Class(stringLiteral: lhs.class + " " + rhs.class)
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
    
    public func ast<E: ElementLike>(input: I) -> E where E.N.Input == () {
        return E(name: name, block: block, attributes: attributes, children: children.map { $0.ast(input: input) })
    }
}

extension Node {
    func render(input: I, encodeText: (String) -> String = { $0.addingUnicodeEntities }) -> String {
        switch self {
        case ._none: return ""
        case ._text(let s): return encodeText(s)
        case ._raw(let s): return s
        case ._withInput(let f): return f(input).render(input: input, encodeText: encodeText)
        case ._node(let n): return n.render(input: input, encodeText: encodeText)
        }
    }
    
    public func ast<N: NodeLike>(input: I) -> N where N.Input == () {
        switch self {
        case ._none:
            return .none()
        case let ._node(n):
            return .node(n.ast(input: input))
        case let ._withInput(f):
            return f(input).ast(input: input)
        case let ._text(t):
            return .text(t)
        case let ._raw(r):
            return .raw(r)
        }
    }
    
    
    public func htmlDocument(input: I) -> String {
        let x: RenderedHTML = ast(input: input)
        return ["<!DOCTYPE html>", x.string].joined(separator: "\n")
    }
}

//extension NodeLike where  {
//    public func htmlDocument(input: Input) -> String {
//        let x: RenderedHTML = ast(input: input)
//        return ["<!DOCTYPE html>", x.string].joined(separator: "\n")
//    }
//}

extension NodeLike {
    public static func html(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "html", class: `class`, attributes: attributes, children: children))
    }
    
    public static func meta(attributes: [String:String] = [:]) -> Self {
        return .node(Element(name: "meta", block: false, attributes: attributes, children: []))
    }
    
    public static func body(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element.init(name: "body", class: `class`, attributes: attributes, children: children))
    }
    
    public static func p(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self]) -> Self {
        return .node(Element(name: "p", class: `class`, attributes: attributes, children: children))
    }
    
    public static func head(attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "head", attributes: attributes, children: children))
    }
    
    public static func header(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "header", class: `class`, attributes: attributes, children: children))
    }
    
    public static func title(_ text: String) -> Self {
        return .node(Element(name: "title", block: false, children: [.text(text)]))
    }

    public static var br: Self {
        return .node(Element(name: "br", block: false))
    }
    
    public static func span(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self]) -> Self {
        return .node(Element(name: "span", block: false, class: `class`, attributes: attributes, children: children))
    }

    public static func strong(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self]) -> Self {
        return .node(Element(name: "strong", block: false, class: `class`, attributes: attributes, children: children))
    }

    public static func h1(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self]) -> Self {
        return .node(Element(name: "h1", block: false, class: `class`, attributes: attributes, children: children))
    }
    
    public static func h2(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self]) -> Self {
        return .node(Element(name: "h2", block: false, class: `class`, attributes: attributes, children: children))
    }
    
    public static func h3(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self]) -> Self {
        return .node(Element(name: "h3", block: false, class: `class`, attributes: attributes, children: children))
    }
    
    public static func h4(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self]) -> Self {
        return .node(Element(name: "h4", block: false, class: `class`, attributes: attributes, children: children))
    }
    
    public static func img(class: Class? = nil, src: String, alt: String = "", attributes: [String:String] = [:]) -> Self {
        var a = attributes
        a["src"] = src
        a["alt"] = alt
        return .node(Element(name: "img", block: false, class: `class`, attributes: a, children: []))
    }
    
    public static func i(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "i", block: true, class: `class`, attributes: attributes, children: children))
    }
    
    public static func div(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "div", class: `class`, attributes: attributes, children: children))
    }
    
    public static func fieldset(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "fieldset", class: `class`, attributes: attributes, children: children))
    }
    
    public static func label(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "label", class: `class`, attributes: attributes, children: children))
    }
    
    public static func table(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "table", class: `class`, attributes: attributes, children: children))
    }
    
    public static func thead(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "thead", class: `class`, attributes: attributes, children: children))
    }
    
    public static func tbody(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "tbody", class: `class`, attributes: attributes, children: children))
    }
    
    public static func tr(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "tr", class: `class`, attributes: attributes, children: children))
    }
    
    public static func td(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "td", class: `class`, attributes: attributes, children: children))
    }
    
    public static func th(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "th", class: `class`, attributes: attributes, children: children))
    }
    
    public static func input(class: Class? = nil, name: String, id: String? = nil, type: String = "text",  attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        var a = attributes
        a["type"] = type
        a["name"] = name
        a["id"] = id ?? name
        a["type"] = type
        if type == "number" {
            a["inputmode"] = "numeric"
            a["pattern"] = "[0-9]*"
        }
        return .node(Element(name: "input", class: `class`, attributes: a, children: children))
    }
    
    public static func textArea(class: Class? = nil, name: String, id: String? = nil, value: String? = nil, placeHolder: String? = nil, rows: Int? = nil, cols: Int? = nil, attributes: [String:String] = [:]) -> Self {
        var a = attributes
        a["name"] = name
        a["id"] = id ?? name
        if let r = rows { a["rows"] = "\(r)" }
        if let c = cols { a["cols"] = "\(c)" }
        if let p = placeHolder { a["placeholder"] = p }
        return .node(Element(name: "textarea", class: `class`, attributes: a, children: [.text(value ?? "")]))
    }

    public static func form(class: Class? = nil, action: String, acceptCharset: String = "UTF-8", method: HTTPMethod = .post, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        var a = attributes
        a["action"] = action
        a["accept-charset"] = acceptCharset
        a["method"] = method.rawValue
        return .node(Element(name: "form", class: `class`, attributes: a, children: children))
    }
    
    public static func aside(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "div", class: `class`, attributes: attributes, children: children))
    }
    
    public static func iframe(source: URL, attributes: [String:String] = [:]) -> Self {
        var attrs = attributes
        attrs["src"] = source.absoluteString
        return .node(Element(name: "iframe", attributes: attrs))
    }
        
    public static func video(class: Class? = nil, source: URL, sourceType: String, attributes: [String:String] = [:]) -> Self {
        return .node(Element(name: "video", class: `class`, attributes: attributes, children: [
            .node(Element(name: "source", attributes: [
                "src": source.absoluteString,
                "type": sourceType
            ]))
        ]))
    }
    
    public static func nav(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "nav", class: `class`, attributes: attributes, children: children))
    }
    
    public static func ul(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "ul", class: `class`, attributes: attributes, children: children))
    }
    
    public static func dl(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "dl", class: `class`, attributes: attributes, children: children))
    }
    
    public static func ol(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "ol", class: `class`, attributes: attributes, children: children))
    }
    
    public static func li(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "li", class: `class`, attributes: attributes, children: children))
    }
    
    public static func dt(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "dt", class: `class`, attributes: attributes, children: children))
    }
    
    public static func dd(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "dd", class: `class`, attributes: attributes, children: children))
    }
    
    public static func button(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "button", class: `class`, attributes: attributes, children: children))
    }
    
    public static func main(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "main", class: `class`, attributes: attributes, children: children))
    }
    
    public static func section(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "section", class: `class`, attributes: attributes, children: children))
    }
    
    public static func article(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "article", class: `class`, attributes: attributes, children: children))
    }
    
    public static func figure(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "figure", class: `class`, attributes: attributes, children: children))
    }
    
    public static func footer(class: Class? = nil, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        return .node(Element(name: "footer", class: `class`, attributes: attributes, children: children))
    }

    public static func script(src: String) -> Self {
        return .node(Element(name: "script", attributes: [
            "src": src
		], children: []))
    }

    public static func script(code: String) -> Self {
        return .node(Element.init(name: "script", children: [.raw(code)]))
    }
    
    public static func xml(name: String, attributes: [String:String] = [:], _ children: [Self] = []) -> Self {
        let block: Bool
        if children.isEmpty {
            block = false
            // TODO
//        } else if children.count == 1 { // , case .text = children[0] { // todo
//            fatalError()
//            block = false
        } else {
            block = true
        }
        return .node(Element(name: name, block: block, attributes: attributes, children: children))
    }
    
    public static func stylesheet(media: String = "all", href: String) -> Self {
        let attributes = [
            "rel": "stylesheet",
            "href": href,
            "media": media
        ]
        return .node(Element(name: "link", attributes: attributes, children: []))
    }

        
    public static func a(class: Class? = nil, href: String, attributes: [String:String] = [:], _ children: [Self]) -> Self {
        assert(attributes["href"] == nil)
        var att = attributes
        att["href"] = href
        return .node(Element(name: "a", block: false, class: `class`, attributes: att, children: children))
    }
}

extension NodeLike {
    public init(stringLiteral: String) {
        self = .text(stringLiteral)
    }
}

extension Node where I == () {
    public var xmlDocument: String {
        return ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", render(input: (), encodeText: { $0.xmlString })].joined(separator: "\n")
    }
}

