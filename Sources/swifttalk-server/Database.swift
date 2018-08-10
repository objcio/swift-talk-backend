//
//  Database.swift
//  Bits
//
//  Created by Chris Eidhof on 08.08.18.
//

import Foundation
import PostgreSQL

fileprivate let migrations: [String] = [
//    """
//    DROP TABLE IF EXusers IF EXISTS
//    """,
//    """
//    DROP TABLE sessions
//    """,
    """
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
    """,
    """
    CREATE TABLE IF NOT EXISTS users (
        id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        email character varying,
        github_uid integer,
        github_login character varying,
        github_token character varying,
        avatar_url character varying,
        name character varying,
        remember_created_at timestamp,
        admin boolean DEFAULT false NOT NULL,
        created_at timestamp NOT NULL,
        updated_at timestamp NOT NULL,
        recurly_hosted_login_token character varying,
        payment_method_id uuid,
        last_reconciled_at timestamp,
        receive_new_episode_emails boolean DEFAULT true,
        collaborator boolean,
        download_credits integer DEFAULT 0 NOT NULL
    );
    """,
    """
    CREATE TABLE IF NOT EXISTS sessions (
        id uuid DEFAULT public.uuid_generate_v4() PRIMARY KEY,
        user_id uuid REFERENCES users NOT NULL,
        created_at timestamp NOT NULL,
        updated_at timestamp NOT NULL
    );
    """,
    """
    ALTER TABLE users ADD IF NOT EXISTS subscriber boolean
    """
]


protocol Insertable: Codable {
    associatedtype InsertionResult = ()
    static var tableName: String { get }
    static var returning: String? { get }
    static var parse: (PostgreSQL.Node) throws -> InsertionResult { get }
}

extension Insertable where InsertionResult == () {
    static var parse: ((PostgreSQL.Node) throws -> ()) { return { _ in return () } }
}

struct Database {
    let connection: Connection
    init(_ c: Connection) {
        self.connection = c
    }
    
    func migrate() throws {
        for m in migrations { // global variable, but we could inject it at some point.
            try connection.execute(m)
        }
    }
}

struct UserResult {
    var id: UUID
    var data: UserData
}

extension Database {
    func insert<E: Insertable>(_ item: E) throws -> E.InsertionResult {
        let result = try insert(item, into: E.tableName, returning: E.returning)
        return try E.parse(result)
    }
    
    private func insert<E: Encodable>(_ item: E, into table: String, returning: String? = nil) throws -> PostgreSQL.Node {
        let fields = try PostgresEncoder.encode(item)
        let fieldNames = fields.map { $0.0 }.joined(separator: ",")
        let placeholders = zip(fields, 1...).map { "$\($0.1)" }.joined(separator: ",")
        var query = "INSERT INTO \(table) (\(fieldNames)) VALUES (\(placeholders))"
        if let r = returning {
            query.append("RETURNING (\(r))")
        }
        return try connection.execute(query, fields.map { $0.1 })
    }

    func user(for session: UUID) throws -> UserData? {
        let fields = PropertiesDecoder.decode(UserData.self).map { "u.\($0.snakeCased)" }.joined(separator: ",")
        let query = "SELECT \(fields) FROM users AS u INNER JOIN sessions AS s ON s.user_id = u.id WHERE s.id = $1"
        let node = try connection.execute(query, [session])
        let users = PostgresNodeDecoder.decode([UserData].self, transformKey: { $0.snakeCased }, node: node)
        assert(users.count <= 1)
        return users.first
    }
}

extension String {
    // todo attribution: copied from swift's standard library
    fileprivate var snakeCased: String {
        guard !self.isEmpty else { return self }
        let stringKey = self // todo inline
        
        var words : [Range<String.Index>] = []
        // The general idea of this algorithm is to split words on transition from lower to upper case, then on transition of >1 upper case characters to lowercase
        //
        // myProperty -> my_property
        // myURLProperty -> my_url_property
        //
        // We assume, per Swift naming conventions, that the first character of the key is lowercase.
        var wordStart = stringKey.startIndex
        var searchRange = stringKey.index(after: wordStart)..<stringKey.endIndex
        
        // Find next uppercase character
        while let upperCaseRange = stringKey.rangeOfCharacter(from: CharacterSet.uppercaseLetters, options: [], range: searchRange) {
            let untilUpperCase = wordStart..<upperCaseRange.lowerBound
            words.append(untilUpperCase)
            
            // Find next lowercase character
            searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
            guard let lowerCaseRange = stringKey.rangeOfCharacter(from: CharacterSet.lowercaseLetters, options: [], range: searchRange) else {
                // There are no more lower case letters. Just end here.
                wordStart = searchRange.lowerBound
                break
            }
            
            // Is the next lowercase letter more than 1 after the uppercase? If so, we encountered a group of uppercase letters that we should treat as its own word
            let nextCharacterAfterCapital = stringKey.index(after: upperCaseRange.lowerBound)
            if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
                // The next character after capital is a lower case character and therefore not a word boundary.
                // Continue searching for the next upper case for the boundary.
                wordStart = upperCaseRange.lowerBound
            } else {
                // There was a range of >1 capital letters. Turn those into a word, stopping at the capital before the lower case character.
                let beforeLowerIndex = stringKey.index(before: lowerCaseRange.lowerBound)
                words.append(upperCaseRange.lowerBound..<beforeLowerIndex)
                
                // Next word starts at the capital before the lowercase we just found
                wordStart = beforeLowerIndex
            }
            searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
        }
        words.append(wordStart..<searchRange.upperBound)
        let result = words.map({ (range) in
            return stringKey[range].lowercased()
        }).joined(separator: "_")
        return result
    }
}



public final class PropertiesDecoder: Decoder {
    static func decode<T: Decodable>(_ type: T.Type) -> [String] {
        let d = PropertiesDecoder()
        _ = try! T(from: d)
        return d.fields
    }
    public var codingPath: [CodingKey] { return [] }
    
    public var userInfo: [CodingUserInfoKey : Any] { return [:] }
    
    private var fields: [String] = []
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(KDC(self))
    }
    
    struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let decoder: PropertiesDecoder
        init(_ decoder: PropertiesDecoder) {
            self.decoder = decoder
        }

        var codingPath: [CodingKey] { return [] }
        
        var allKeys: [Key] { return [] }
        
        func contains(_ key: Key) -> Bool {
            return true
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            decoder.fields.append(key.stringValue)
            return true
        }
        
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            decoder.fields.append(key.stringValue)
            return true
        }
        
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            decoder.fields.append(key.stringValue)
            return ""
        }
        
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            decoder.fields.append(key.stringValue)
            return 0
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            decoder.fields.append(key.stringValue)
            if type == Date.self {
                return Date() as! T
            } else {
                return try T(from: decoder)
            }
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
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError()
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError()
    }
}

public final class PostgresNodeDecoder: Decoder {
    static func decode<T: Decodable>(_ type: T.Type, transformKey: @escaping (String) -> String = { $0.snakeCased }, node: PostgreSQL.Node) -> T {
        let d = PostgresNodeDecoder(node, transformKey: transformKey)
        return try! T(from: d)
    }
    
    let node: PostgreSQL.Node
    let transformKey: (String) -> String
    
    init(_ node: PostgreSQL.Node, transformKey: @escaping (String) -> String) {
        self.node = node
        self.transformKey = transformKey
    }
    
    public var codingPath: [CodingKey] { return [] }
    
    public var userInfo: [CodingUserInfoKey : Any] { return [:] }
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(KDC(node, transformKey: transformKey))
    }
    
    struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        let node: PostgreSQL.Node
        let transformKey: (String) -> String
        init(_ node: PostgreSQL.Node, transformKey: @escaping (String) -> String) {
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
            if T.self == Date.self {
                return try (decode(key) as Date) as! T
            } else {
                fatalError("key: \(key), type: \(type)")
            }
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
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UDC(node.array!, transformKey: transformKey)
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError()
    }
    
    struct UDC: UnkeyedDecodingContainer {
        let nodes: [PostgreSQL.Node]
        let transformKey: (String) -> String
        
        init(_ nodes: [PostgreSQL.Node], transformKey: @escaping (String) -> String) {
            self.nodes = nodes
            self.transformKey = transformKey
        }
        
        var codingPath: [CodingKey] = []
        
        var count: Int? { return nodes.count }
        
        var isAtEnd: Bool { return currentIndex >= nodes.count }
        
        var currentIndex: Int = 0
        
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
}


public final class PostgresEncoder: Encoder {
    static func encode(_ c: Encodable, transform: @escaping (String) -> String = { $0.snakeCased }) throws -> [(String, NodeRepresentable)] {
        let e = PostgresEncoder(transform)
        try c.encode(to: e)
        return e.result
    }
    
    public var codingPath: [CodingKey] { return [] }
    public var userInfo: [CodingUserInfoKey : Any] { return [:] }
    var result: [(String, NodeRepresentable)] = []
    let transform: (String) -> String
    
    init(_ transform: @escaping (String) -> String){
        self.transform = transform
    }
    
    public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(KEC(self, transformKey: transform))
    }
    
    struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var codingPath: [CodingKey] = []
        let transformKey: (String) -> String
        
        let encoder: PostgresEncoder
        init(_ e: PostgresEncoder, transformKey: @escaping (String) -> String) {
            encoder = e
            self.transformKey = transformKey
        }
        
        mutating func push(_ key: Key, _ value: NodeRepresentable) {
            encoder.result.append((transformKey(key.stringValue), value))
        }
        
        mutating func encodeNil(forKey key: Key) throws {
            push(key, Optional<String>.none) // todo is it a good idea to use a string optional?
        }
        
        mutating func encodeNode<N: NodeRepresentable>(_ value: N, forKey key: Key) throws {
            push(key, value)
        }
        
        mutating func encode(_ value: Bool, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: String, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: Double, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: Float, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: Int, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: Int8, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: Int16, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: Int32, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: Int64, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: UInt, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: UInt8, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: UInt16, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: UInt32, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode(_ value: UInt64, forKey key: Key) throws {
            try encodeNode(value, forKey: key)
        }
        
        mutating func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
            if let n = value as? NodeRepresentable {
                push(key, n)
            } else {
                fatalError()
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
    
    public func unkeyedContainer() -> UnkeyedEncodingContainer {
        fatalError()
    }
    
    public func singleValueContainer() -> SingleValueEncodingContainer {
        fatalError()
    }
}

