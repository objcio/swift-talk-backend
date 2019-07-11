//
//  Query.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import LibPQ
import Base

public struct Query<A> {
    public var query: QueryStringAndParams
    var parse: (QueryResult) -> A
    public init(_ query: QueryStringAndParams, parse: @escaping (QueryResult) -> A) {
        self.query = query
        self.parse = parse
    }
}

public struct QueryStringAndParams {
    enum Part {
        case raw(String)
        case value(Param)
    }
    
    var parts: [Part]
}

extension QueryStringAndParams: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        // todo: assert that the value doesn't contain any $0, $1, etc?
        parts = [.raw(value)]
    }
}

extension QueryStringAndParams: ExpressibleByStringInterpolation, StringInterpolationProtocol {
    public init(literalCapacity: Int, interpolationCount: Int) {
        self.parts = []
    }
    
    public var rendered: (sql: String, values: [Param]) {
        var start = 1
        var result = ""
        var values: [Param] = []
        for part in parts {
            switch part {
            case let .raw(s): result.append(s)
            case let .value(v):
                result.append("$\(start)")
                values.append(v)
                start += 1
            }
            result.append(" ")
        }
        return (sql: result, values: values)
    }
    
    public typealias StringInterpolation = QueryStringAndParams
    
    public mutating func appendLiteral(_ x: String) {
        guard x.count > 0 else { return }
        parts.append(.raw(x))
    }
    
    // todo this could be a protocol "Safe Identifier" or similar
    public mutating func appendInterpolation(_ t: TableName) {
        parts.append(.raw(t.name))
    }
    
    public mutating func appendInterpolation(raw x: String) {
        guard x.count > 0 else { return }
        parts.append(.raw(x))
    }
    
    public mutating func appendInterpolation(param n: Param) {
        parts.append(.value(n))
    }
    
    public mutating func appendInterpolation(values: FieldValues) {
        parts.append(.raw("(\(values.fieldList)) VALUES ("))
        parts.append(contentsOf: values.values.map { .value($0) }.intersperse(.raw(",")))
        parts.append(.raw(")"))
    }
    
    public init(stringInterpolation: QueryStringAndParams) {
        self = stringInterpolation
    }
}

extension QueryStringAndParams {
    public mutating func append(_ other: QueryStringAndParams) {
        parts.append(contentsOf: other.parts)
    }
    
    public func appending(_ other: QueryStringAndParams) -> QueryStringAndParams {
        var copy = self
        copy.append(other)
        return copy
    }
}
    

extension Query {
    public func map<B>(_ transform: @escaping (A) -> B) -> Query<B> {
        return Query<B>(query) { node in
            return transform(self.parse(node))
        }
    }
    
    public mutating func append(_ other: QueryStringAndParams) {
        query.append(other)
    }
    
    public func appending(_ other: QueryStringAndParams) -> Query {
        var copy = self
        copy.append(other)
        return copy
    }
}

