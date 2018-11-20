//
//  RecurlyXMLDecoder.swift
//  Bits
//
//  Created by Chris Eidhof on 13.08.18.
//

//import Foundation
import PerfectXML

struct DecodingError: Error {
    let message: String
}

extension XMLNode {
    fileprivate func contents() throws -> String? {
        guard let c = children else { return "" }
        var result: String = ""
        for child in c {
            guard child.kind == .text else { throw DecodingError(message: "Expected text, but got \(child)") }
            result += child.stringValue ?? ""
        }
        return result
    }
}

extension DateFormatter {
    static let iso8601WithTimeZone: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return dateFormatter
    }()
}


fileprivate final class RecurlyXMLDecoder: Decoder {
    var node: XElement
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]
    init(_ element: XElement) {
        self.node = element
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key: CodingKey {
        return KeyedDecodingContainer(KDC(node))
    }
    
    struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let node: XElement
        init(_ node: XElement) {
            self.node = node
        }
        
        var codingPath: [CodingKey] = []
        
        var allKeys: [Key] {
            fatalError("\(#function), \(#line)")
        }
        
        func contains(_ key: Key) -> Bool {
            return node.childNodes.contains { $0.nodeName == key.stringValue }
        }
        
        func child(key: Key) -> XElement? {
            return node.childNodes.first { $0.nodeName == key.stringValue }.flatMap { $0 as? XElement }
        }
        
        func requireChild(key: Key) throws -> XElement {
            let result = node.childNodes.first { $0.nodeName == key.stringValue }.flatMap { $0 as? XElement }
            if let x = result {
                return x
            } else {
                throw DecodingError(message: "Expected node \"\(key.stringValue)\" but got none (context: \(node.string()))")
            }
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            guard let c = child(key: key) else {
                return true
            }
            return c.getAttribute(name: "nil") != nil
        }
        
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            guard let c = try requireChild(key: key).nodeValue else {
                throw DecodingError(message: "Expected a string for key: \(key)")
            }
            switch c {
            case "true": return true
            case "false": return false
            default: throw DecodingError(message: "Expected a bool but got \(c)")
            }
        }
        
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            guard let c = try requireChild(key: key).nodeValue else {
                throw DecodingError(message: "Expected a string for key: \(key) context: \(node)")
            }
            return c
        }
        
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            guard let c = child(key: key)?.nodeValue, let d = Double(c) else {
                throw DecodingError(message: "Expected a string for key: \(key)")
            }
            return d
            
        }
        
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            guard let c = child(key: key)?.nodeValue, let d = Float(c) else {
                throw DecodingError(message: "Expected a string for key: \(key)")
            }
            return d
        }
        
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            guard let c = child(key: key)?.nodeValue, let i = Int(c) else {
                throw DecodingError(message: "Expected a string for key: \(key)")
            }
            return i
        }
        
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            let node = try requireChild(key: key)
            if type == URL.self {
                guard let value = node.getAttribute(name:  "href") else {
                    throw DecodingError(message: "Expected a \"href\" attribute")
                }
                guard let u = URL(string: value) else {
                    throw DecodingError(message: "Malformed URL in node: \(node.string())")
                }
                return u as! T
            } else if type == Date.self {
                guard let c = node.nodeValue else { throw DecodingError(message: "Expected a date, got nothing") }
                guard let d = DateFormatter.iso8601WithTimeZone.date(from: c) else { throw DecodingError(message: "Malformatted date: \(c)") }
                return d as! T
            } else if type == RecurlyError.self {
                let field = node.getAttribute(name: "field")
                let symbol = node.getAttribute(name: "symbol")
                return RecurlyError(field: field, symbol: symbol, message: node.nodeValue ?? "") as! T
            }
            let decoder = RecurlyXMLDecoder(node)
            return try T(from: decoder)
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError("\(#function), \(#line)")
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            fatalError("\(#function), \(#line)")
        }
        
        func superDecoder() throws -> Decoder {
            fatalError("\(#function), \(#line)")
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            fatalError("\(#function), \(#line)")
        }
    }
    
    struct UDC: UnkeyedDecodingContainer {
        let nodes: [XElement]
        var codingPath: [CodingKey]
        var count: Int? { return nodes.count }
        var isAtEnd: Bool { return currentIndex >= nodes.count }
        var currentIndex: Int
        
        mutating func err<T: Decodable>() throws -> T {
            throw DecodingError(message: "Can't decode")
        }
        mutating func decodeNil() throws -> Bool {
            return try err()
        }
        
        mutating func decode(_ type: Bool.Type) throws -> Bool {
            return try err()
        }
        
        mutating func decode(_ type: String.Type) throws -> String {
            return try err()
        }
        
        mutating func decode(_ type: Double.Type) throws -> Double {
            return try err()
        }
        
        mutating func decode(_ type: Float.Type) throws -> Float {
            return try err()
        }
        
        mutating func decode(_ type: Int.Type) throws -> Int {
            return try err()
        }
        
        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            return try err()
        }
        
        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            return try err()
        }
        
        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            return try err()
        }
        
        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            return try err()
        }
        
        mutating func decode(_ type: UInt.Type) throws -> UInt {
            return try err()
        }
        
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            return try err()
        }
        
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            return try err()
        }
        
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            return try err()
        }
        
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            return try err()
        }
        
        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
          	let node = nodes[currentIndex]
            currentIndex += 1
            if type == RecurlyError.self {
                let field = node.getAttribute(name: "field")
                let symbol = node.getAttribute(name: "symbol")
                return RecurlyError(field: field, symbol: symbol, message: node.nodeValue ?? "") as! T
            } else {
                let decoder = RecurlyXMLDecoder(node)
                return try T(from: decoder)
            }
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func superDecoder() throws -> Decoder {
            fatalError("\(#function), \(#line)")
        }
        
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UDC(nodes: node.childNodes.compactMap { $0 as? XElement }, codingPath: [], currentIndex: 0)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SVDC(node)
    }
    
    struct SVDC: SingleValueDecodingContainer {
        let node: XNode
        var codingPath: [CodingKey] = []
        
        func decodeNil() -> Bool {
            if node.nodeName != nil {
                return false
            }
            return true
        }
        
        func decode(_ type: Bool.Type) throws -> Bool {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: String.Type) throws -> String {
            guard let c = node.nodeValue else {
                throw DecodingError(message: "Expected a string in \(node)")
            }
            return c
        }
        
        func decode(_ type: Double.Type) throws -> Double {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Float.Type) throws -> Float {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Int.Type) throws -> Int {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Int8.Type) throws -> Int8 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Int16.Type) throws -> Int16 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Int32.Type) throws -> Int32 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: Int64.Type) throws -> Int64 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt.Type) throws -> UInt {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt8.Type) throws -> UInt8 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt16.Type) throws -> UInt16 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt32.Type) throws -> UInt32 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode(_ type: UInt64.Type) throws -> UInt64 {
            fatalError("\(#function), \(#line)")
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            return try T.init(from: RecurlyXMLDecoder(node as! XElement))
        }
        
        init(_ node: XNode) {
            self.node = node
        }
    }
}

import Foundation
// Decodes the children of the document's root element
func decodeXML<T: Decodable>(from data: Data) throws -> T {
    let doc = XDocument(fromSource: String(data: data, encoding: .utf8)!)
    guard let x = doc?.documentElement else {
        throw DecodingError(message: "Couldn't parse XML")
    }
    let decoder = RecurlyXMLDecoder(x)
    return try T(from: decoder)
}

extension El {
    init(_ name: String, contents: String) {
        self.init(name: name, block: false, classes: nil, attributes: [:], children: [.text(contents)])
    }
    
    mutating func add(child: El) {
        children.append(.node(child))
    }
}

final class RecurlyXMLEncoder: Encoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]
    var rootElement: El
    func add(child el: El) {
        rootElement.add(child: el)
    }
    init(_ name: String) {
        rootElement = El(name: name, block: true, classes: nil, attributes: [:], children: [])
    }
    
    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(KEC(self))
    }
    
    struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
        let encoder: RecurlyXMLEncoder
        init(_ encoder: RecurlyXMLEncoder) {
            self.encoder = encoder
        }
        var codingPath: [CodingKey] = []
        
        mutating func encodeNil(forKey key: Key) throws {
            encoder.add(child: El(name: key.stringValue, attributes: ["nil": "nil"], children: []))
        }
        
        mutating func encode(_ value: Bool, forKey key: Key) throws {
            encoder.add(child: El(key.stringValue, contents: "\(value)"))
        }
        
        mutating func encode(_ value: String, forKey key: Key) throws {
            encoder.add(child: El(key.stringValue, contents: value))
        }
        
        mutating func encode(_ value: Double, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Float, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int, forKey key: Key) throws {
            encoder.add(child: El(key.stringValue, contents: String(value)))
        }
        
        mutating func encode(_ value: Int8, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int16, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int32, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int64, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt8, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt16, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt32, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt64, forKey key: Key) throws {
            fatalError()
        }
        
        mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            if let uuid = value as? UUID {
                encoder.add(child: El(key.stringValue, contents: uuid.uuidString))
            } else {
                let childEncoder = RecurlyXMLEncoder(key.stringValue)
                try value.encode(to: childEncoder)
                encoder.add(child: childEncoder.rootElement)
            }
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
            fatalError()
        }
        
        mutating func superEncoder() -> Encoder {
            fatalError()
        }
        
        mutating func superEncoder(forKey key: Key) -> Encoder {
            fatalError()
        }
        
        
    }
    
    
    struct UEC: UnkeyedEncodingContainer {
        var codingPath: [CodingKey] = []
        var count: Int = 0

        let encoder: RecurlyXMLEncoder
        init(_ encoder: RecurlyXMLEncoder) {
            self.encoder = encoder
        }

        mutating func encode(_ value: String) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Double) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Float) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int8) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int16) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int32) throws {
            fatalError()
        }
        
        mutating func encode(_ value: Int64) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt8) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt16) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt32) throws {
            fatalError()
        }
        
        mutating func encode(_ value: UInt64) throws {
            fatalError()
        }
        
        mutating func encode<T>(_ value: T) throws where T : Encodable {
            if let v = value as? RootElement {
                let childEncoder = RecurlyXMLEncoder(type(of: v).rootElementName)
                try value.encode(to: childEncoder)
                encoder.add(child: childEncoder.rootElement)
            } else {
                fatalError()
            }
        }
        
        mutating func encode(_ value: Bool) throws {
            fatalError()
        }

        mutating func encodeNil() throws {
            fatalError()
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
            fatalError()
        }
        
        mutating func superEncoder() -> Encoder {
            fatalError()
        }
        
        
    }
    
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return UEC(self)
    }
    
    func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError()
    }
    
    
}

protocol RootElement {
    static var rootElementName: String { get }
}

func encodeXML<T: Encodable>(_ value: T) throws -> String where T: RootElement {
    let encoder = RecurlyXMLEncoder(T.rootElementName)
    try value.encode(to: encoder)
    return Node.node(encoder.rootElement).xmlDocument
}

fileprivate extension Node {
    var xmlDocument: String {
        return ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>", render(encodeText: { $0.xmlString })].joined(separator: "\n")
    }
}

fileprivate extension String {
    var xmlString: String {
        var result = ""
        result.reserveCapacity(count)
        for c in self {
            switch c {
            case "&": result.append("&amp")
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

