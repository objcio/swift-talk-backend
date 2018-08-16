//
//  Database.swift
//  Bits
//
//  Created by Chris Eidhof on 08.08.18.
//

import Foundation
import PostgreSQL

let postgreSQL = try? PostgreSQL.Database(connInfo: postgresConfig)

func withConnection<A>(_ x: (Connection?) throws -> A) rethrows -> A {
    let conn: Connection? = postgreSQL.flatMap {
        do {
            let conn = try $0.makeConnection()
            return conn
        } catch {
            print(error, to: &standardError)
            print(error.localizedDescription, to: &standardError)
            return nil
        }
    }
    let result = try x(conn)
    try? conn?.close()
    return result
}

protocol Insertable: Codable {
    static var tableName: String { get }
}

extension Insertable {
    var fieldNamesAndValues: [(String, NodeRepresentable)] {
        let m = Mirror(reflecting: self)
        return m.children.map { ($0.label!.snakeCased, $0.value as! NodeRepresentable) }
    }
    
    static var fieldNames: [String] {
        return try! PropertyNamesDecoder.decode(UserData.self).map { $0.snakeCased }
    }
    
    var insert: Query<UUID> {
        let fields = fieldNamesAndValues
        let names = fields.map { $0.0 }.joined(separator: ",")
        let values = fields.map { $0.1 }
        let placeholders = (1...fields.count).map { "$\($0)" }.joined(separator: ",")
        let query = "INSERT INTO \(Self.tableName) (\(names)) VALUES (\(placeholders)) RETURNING id"
        return Query(query: query, values: values, parse: { node in
            return UUID(uuidString: node[0, "id"]!.string!)!
        })
    }
}


extension Connection {
    func execute<A>(_ query: Query<A>) throws -> A {
        let node = try execute(query.query, query.values)
        return query.parse(node)
    }
}


public final class PostgresNodeDecoder: Decoder {
    private let node: PostgreSQL.Node
    private let transformKey: (String) -> String

    public var codingPath: [CodingKey] { return [] }
    public var userInfo: [CodingUserInfoKey : Any] { return [:] }
    
    static func decode<T: Decodable>(_ type: T.Type, transformKey: @escaping (String) -> String = { $0.snakeCased }, node: PostgreSQL.Node) -> T {
        let d = PostgresNodeDecoder(node, transformKey: transformKey)
        return try! T(from: d)
    }
    
    fileprivate init(_ node: PostgreSQL.Node, transformKey: @escaping (String) -> String) {
        self.node = node
        self.transformKey = transformKey
    }
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(KDC(decoder: self, node: node, transformKey: transformKey))
    }

    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UDC(node.array!, transformKey: transformKey)
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SVC(decoder: self, node: node)
    }

    private struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        private let decoder: Decoder
        private let node: PostgreSQL.Node
        private let transformKey: (String) -> String
        init(decoder: Decoder, node: PostgreSQL.Node, transformKey: @escaping (String) -> String) {
            self.decoder = decoder
            self.node = node
            self.transformKey = transformKey
        }
        
        var codingPath: [CodingKey] { return [] }
        
        var allKeys: [Key] { return [] }
        
        func contains(_ key: Key) -> Bool {
            return node[transformKey(key.stringValue)] != nil
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            guard let value = node[transformKey(key.stringValue)] else { fatalError() }
            return value.isNull
        }
        
        func decode<T: NodeInitializable>(_ key: Key) throws -> T {
            // todo parameterize the snake casing
            guard let value = node[transformKey(key.stringValue)] else { fatalError("key: \(key), container: \(node)") }
            return try value.converted(to: T.self)
        }

        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            return try decode(key)
        }
        
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            return try decode(key)
        }
        
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            return try decode(key)
        }
        
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            return try decode(key)
        }
        
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            return try decode(key)
        }
        
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            return try decode(key)
        }
        
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            return try decode(key)
        }
        
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            return try decode(key)
        }
        
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            return try decode(key)
        }
        
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            return try decode(key)
        }
        
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            return try decode(key)
        }
        
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            return try decode(key)
        }
        
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            return try decode(key)
        }
        
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            return try decode(key)
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            guard let newNode = node[transformKey(key.stringValue)] else { fatalError() }
            let decoder = PostgresNodeDecoder(newNode, transformKey: transformKey)
            return try T(from: decoder)
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            fatalError()
        }
        
        func superDecoder() throws -> Decoder {
            fatalError()
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            fatalError()
        }
    }
    
    private struct UDC: UnkeyedDecodingContainer {
        let nodes: [PostgreSQL.Node]
        let transformKey: (String) -> String
        var codingPath: [CodingKey] = []
        var count: Int? { return nodes.count }
        var isAtEnd: Bool { return currentIndex >= nodes.count }
        var currentIndex: Int = 0

        init(_ nodes: [PostgreSQL.Node], transformKey: @escaping (String) -> String) {
            self.nodes = nodes
            self.transformKey = transformKey
        }
        
        mutating func decodeNil() throws -> Bool {
            fatalError()
        }
        
        mutating func decode(_ type: Bool.Type) throws -> Bool {
            fatalError()
        }
        
        mutating func decode(_ type: String.Type) throws -> String {
            fatalError()
        }
        
        mutating func decode(_ type: Double.Type) throws -> Double {
            fatalError()
        }
        
        mutating func decode(_ type: Float.Type) throws -> Float {
            fatalError()
        }
        
        mutating func decode(_ type: Int.Type) throws -> Int {
            fatalError()
        }
        
        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            fatalError()
        }
        
        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            fatalError()
        }
        
        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            fatalError()
        }
        
        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            fatalError()
        }
        
        mutating func decode(_ type: UInt.Type) throws -> UInt {
            fatalError()
        }
        
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            fatalError()
        }
        
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            fatalError()
        }
        
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            fatalError()
        }
        
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            fatalError()
        }
        
        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            let decoder = PostgresNodeDecoder(nodes[currentIndex], transformKey: transformKey) // todo not sure if this is a good idea...
            currentIndex += 1
            return try T(from: decoder)
        }
        
        mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
            fatalError()
        }
        
        mutating func superDecoder() throws -> Decoder {
            fatalError()
        }
    }
    
    private struct SVC: SingleValueDecodingContainer {
        let decoder: Decoder
        let node: PostgreSQL.Node
        var codingPath: [CodingKey] = []
        
        init(decoder: Decoder, node: PostgreSQL.Node) {
            self.decoder = decoder
            self.node = node
        }

        func decode<T: NodeInitializable>() throws -> T {
            return try node.converted(to: T.self)
        }
    
        func decodeNil() -> Bool {
            return node.isNull
        }
        
        func decode(_ type: Bool.Type) throws -> Bool {
            return try decode()
        }
        
        func decode(_ type: String.Type) throws -> String {
            return try decode()
        }
        
        func decode(_ type: Double.Type) throws -> Double {
            return try decode()
        }
        
        func decode(_ type: Float.Type) throws -> Float {
            return try decode()
        }
        
        func decode(_ type: Int.Type) throws -> Int {
            return try decode()
        }
        
        func decode(_ type: Int8.Type) throws -> Int8 {
            return try decode()
        }
        
        func decode(_ type: Int16.Type) throws -> Int16 {
            return try decode()
        }
        
        func decode(_ type: Int32.Type) throws -> Int32 {
            return try decode()
        }
        
        func decode(_ type: Int64.Type) throws -> Int64 {
            return try decode()
        }
        
        func decode(_ type: UInt.Type) throws -> UInt {
            return try decode()
        }
        
        func decode(_ type: UInt8.Type) throws -> UInt8 {
            return try decode()
        }
        
        func decode(_ type: UInt16.Type) throws -> UInt16 {
            return try decode()
        }
        
        func decode(_ type: UInt32.Type) throws -> UInt32 {
            return try decode()
        }
        
        func decode(_ type: UInt64.Type) throws -> UInt64 {
            return try decode()
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            return try T(from: decoder)
        }
    }
}
