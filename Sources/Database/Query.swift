//
//  Query.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import PostgreSQL
import Base

public struct Query<A> {
    public var query: QueryStringAndParams
    var parse: (PostgreSQL.Node) -> A
    public init(_ query: QueryStringAndParams, parse: @escaping (PostgreSQL.Node) -> A) {
        self.query = query
        self.parse = parse
    }
}

public struct QueryStringAndParams {
    enum Part {
        case raw(String)
        case value(NodeRepresentable)
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
    
    public var rendered: (sql: String, values: [NodeRepresentable]) {
        var start = 1
        var result = ""
        var values: [NodeRepresentable] = []
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
        parts.append(.raw(x))
    }
    
    // todo this could be a protocol "Safe Identifier" or similar
    public mutating func appendInterpolation(_ t: TableName) {
        parts.append(.raw(t.name))
    }
    
    public mutating func appendInterpolation(raw x: String) {
        parts.append(.raw(x))
    }
    
    public mutating func appendInterpolation(param n: NodeRepresentable) {
        parts.append(.value(n))
    }
    
    public mutating func appendInterpolation(values: [(key: String, value: NodeRepresentable)]) {
        let names = values.map { $0.key }.joined(separator: ",")
        parts.append(.raw("(\(names)) VALUES ("))
        parts.append(contentsOf: values.map { .value($0.value) }.intersperse(.raw(",")))
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
    
    public func appending(_ part: QueryStringAndParams) -> Query<A> {
        return Query(query.appending(part), parse: parse)
    }
}

