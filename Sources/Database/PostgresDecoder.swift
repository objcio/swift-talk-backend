//
//  File.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 26-11-2018.
//

import Foundation
import LibPQ

enum DecodableValue {
    case queryResult(QueryResult)
    case row(LibPQ.Row)
}

public final class PostgresNodeDecoder: Decoder {
    private let result: Tuples
    private let transformKey: (String) -> String
    
    public var codingPath: [CodingKey] { return [] }
    public var userInfo: [CodingUserInfoKey : Any] { return [:] }
    
    static func decode<T: Decodable>(_ type: T.Type, transformKey: @escaping (String) -> String = { $0.snakeCased }, result: Tuples) -> T {
        let d = PostgresNodeDecoder(result, transformKey: transformKey)
        return try! T(from: d)
    }
    
    fileprivate init(_ result: Tuples, transformKey: @escaping (String) -> String) {
        self.result = result
        self.transformKey = transformKey
    }
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        fatalError() // return KeyedDecodingContainer(KDC(decoder: self, result: result, transformKey: transformKey))
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UDC(result, transformKey: transformKey)
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError()
//        return SVC(decoder: self, node: node)
    }
    
    private struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
//        private let decoder: Decoder
        private let result: LibPQ.Row
        private let transformKey: (String) -> String
        init(result: LibPQ.Row, transformKey: @escaping (String) -> String) {
//            self.decoder = decoder
            self.result = result
            self.transformKey = transformKey
        }
        
        var codingPath: [CodingKey] { return [] }
        
        var allKeys: [Key] { return [] }
        
        func contains(_ key: Key) -> Bool {
            return result.result.columnIndex(of: transformKey(key.stringValue)) != nil
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            return result.isNull(index: result.result.columnIndex(of: transformKey(key.stringValue))!)
        }
        
        func decode<T: Param>(_ key: Key) throws -> T {
            guard let value: T = result[name: transformKey(key.stringValue)] else { fatalError("key: \(key), container: \(result)") }
            return value
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
            let name = transformKey(key.stringValue)
            if type == UUID.self {
                return (result[name: name]! as UUID) as! T
            } else if type == Date.self { // todo: could we check that type is NodeConvertible?
                return (result[name: name]! as Date) as! T
            }
            fatalError("TODO")
//            let decoder = PostgresNodeDecoder(newNode, transformKey: transformKey)
//            return try T(from: decoder)
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
    
    private struct UDC: UnkeyedDecodingContainer {
        
        let result: Tuples
        let transformKey: (String) -> String
        var codingPath: [CodingKey] = []
        var count: Int? { return Int(result.count) }
        var isAtEnd: Bool { return currentIndex >= result.count }
        var currentIndex: Int = 0
        
        init(_ result: Tuples, transformKey: @escaping (String) -> String) {
            self.result = result
            self.transformKey = transformKey
        }
        
        mutating func decodeNil() throws -> Bool {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: Bool.Type) throws -> Bool {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: String.Type) throws -> String {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: Double.Type) throws -> Double {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: Float.Type) throws -> Float {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: Int.Type) throws -> Int {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: UInt.Type) throws -> UInt {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            fatalError("\(#function), \(#line)")
        }
        
        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            fatalError("Trying to decode \(T.self)")
//            let row = result[Int32(currentIndex)]
//            let kdc = KDC(result: row, transformKey: transformKey)
////            let decoder = PostgresNodeDecoder(result[Int32(currentIndex)], transformKey: transformKey)
//            currentIndex += 1
//            return kdc.
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
    
    private struct SVC: SingleValueDecodingContainer {
        let decoder: Decoder
        let value: String?
        var codingPath: [CodingKey] = []
        
        init(decoder: Decoder, value: String?) {
            self.decoder = decoder
            self.value = value
        }
        
        func decode<T: Param>() throws -> T {
            return T(stringValue: value!)
        }
        
        func decodeNil() -> Bool {
            return value == nil
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
