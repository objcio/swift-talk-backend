//
//  Database.swift
//  Bits
//
//  Created by Chris Eidhof on 08.08.18.
//

import Foundation
import PostgreSQL

fileprivate let migrations: [String] = [
    """
    	CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;
""",
    """
    	COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';
""",
    """
        CREATE TABLE IF NOT EXISTS users (
        id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
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

extension Database {
    func insert<E: Insertable>(_ item: E) throws -> E.InsertionResult {
        let result = try insert(item, into: E.tableName, returning: E.returning)
        return try E.parse(result)
    }
    
    private func insert<E: Encodable>(_ item: E, into table: String, returning: String? = nil) throws -> PostgreSQL.Node {
        let fields = try PostgresEncoder.encode(item)
        let fieldNames = fields.map { $0.0 }.joined(separator: ",")
        let placeholders = zip(fields, 1...).map { "$\($0.1)" }.joined(separator: ",")
        var query = "INSERT INTO users (\(fieldNames)) VALUES (\(placeholders))"
        if let r = returning {
            query.append("RETURNING (\(r))")
        }
        return try connection.execute(query, fields.map { $0.1 })
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

public final class PostgresEncoder: Encoder {
    static func encode(_ c: Encodable) throws -> [(String, NodeRepresentable)] {
        let e = PostgresEncoder()
        try c.encode(to: e)
        return e.result
    }
    
    public var codingPath: [CodingKey] { return [] }
    public var userInfo: [CodingUserInfoKey : Any] { return [:] }
    var result: [(String, NodeRepresentable)] = []
    
    public func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
        return KeyedEncodingContainer(KEC(self))
    }
    
    struct KEC<Key: CodingKey>: KeyedEncodingContainerProtocol {
        var codingPath: [CodingKey] = []
        
        let encoder: PostgresEncoder
        init(_ e: PostgresEncoder) {
            encoder = e
        }
        
        mutating func push(_ key: Key, _ value: NodeRepresentable) {
            encoder.result.append((key.stringValue.snakeCased, value))
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
