//
//  PropertyNamesDecoder.swift
//  Bits
//
//  Created by Florian Kugler on 13-08-2018.
//

import Foundation

public final class PropertyNamesDecoder: Decoder {
    static func decode<T: Decodable>(_ type: T.Type) throws -> [String] {
        let d = PropertyNamesDecoder()
        _ = try T(from: d)
        return d.fields
    }
    
    public var codingPath: [CodingKey] { return [] }
    public var userInfo: [CodingUserInfoKey : Any] { return [:] }
    private var fields: [String] = []
    
    public func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(KDC(self))
    }
    
    public func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return UDC(self)
    }
    
    public func singleValueContainer() throws -> SingleValueDecodingContainer {
        return SVDC(self)
    }
    
    private struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        private let decoder: PropertyNamesDecoder
        var codingPath: [CodingKey] { return [] }
        var allKeys: [Key] { return [] }
        
        init(_ decoder: PropertyNamesDecoder) {
            self.decoder = decoder
        }
        
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
            let copy = decoder.fields
            defer { decoder.fields = copy }
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
    
    private struct UDC: UnkeyedDecodingContainer {
        private let decoder: Decoder
        var codingPath: [CodingKey] { return [] }
        var count: Int? { return 0 }
        var isAtEnd: Bool { return true }
        var currentIndex: Int { return 0 }
        
        init(_ decoder: Decoder) {
            self.decoder = decoder
        }
        
        mutating func decodeNil() throws -> Bool {
            return true
        }
        
        mutating func decode(_ type: Bool.Type) throws -> Bool {
            return true
        }
        
        mutating func decode(_ type: String.Type) throws -> String {
            return ""
        }
        
        mutating func decode(_ type: Double.Type) throws -> Double {
            return 0
        }
        
        mutating func decode(_ type: Float.Type) throws -> Float {
            return 0
        }
        
        mutating func decode(_ type: Int.Type) throws -> Int {
            return 0
        }
        
        mutating func decode(_ type: Int8.Type) throws -> Int8 {
            return 0
        }
        
        mutating func decode(_ type: Int16.Type) throws -> Int16 {
            return 0
        }
        
        mutating func decode(_ type: Int32.Type) throws -> Int32 {
            return 0
        }
        
        mutating func decode(_ type: Int64.Type) throws -> Int64 {
            return 0
        }
        
        mutating func decode(_ type: UInt.Type) throws -> UInt {
            return 0
        }
        
        mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
            return 0
        }
        
        mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
            return 0
        }
        
        mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
            return 0
        }
        
        mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
            return 0
        }
        
        mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            return try T(from: decoder)
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
    
    private struct SVDC: SingleValueDecodingContainer {
        private let decoder: Decoder
        var codingPath: [CodingKey] { return [] }
        
        init(_ decoder: Decoder) {
            self.decoder = decoder
        }
        
        func decodeNil() -> Bool {
            return true
        }
        
        func decode(_ type: Bool.Type) throws -> Bool {
            return true
        }
        
        func decode(_ type: String.Type) throws -> String {
            return ""
        }
        
        func decode(_ type: Double.Type) throws -> Double {
            return 0
        }
        
        func decode(_ type: Float.Type) throws -> Float {
            return 0
        }
        
        func decode(_ type: Int.Type) throws -> Int {
            return 0
        }
        
        func decode(_ type: Int8.Type) throws -> Int8 {
            return 0
        }
        
        func decode(_ type: Int16.Type) throws -> Int16 {
            return 0
        }
        
        func decode(_ type: Int32.Type) throws -> Int32 {
            return 0
        }
        
        func decode(_ type: Int64.Type) throws -> Int64 {
            return 0
        }
        
        func decode(_ type: UInt.Type) throws -> UInt {
            return 0
        }
        
        func decode(_ type: UInt8.Type) throws -> UInt8 {
            return 0
        }
        
        func decode(_ type: UInt16.Type) throws -> UInt16 {
            return 0
        }
        
        func decode(_ type: UInt32.Type) throws -> UInt32 {
            return 0
        }
        
        func decode(_ type: UInt64.Type) throws -> UInt64 {
            return 0
        }
        
        func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
            return try T(from: decoder)
        }
    }
}

