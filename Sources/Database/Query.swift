//
//  Query.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import PostgreSQL

public struct Query<A> {
    public var query: QueryStringAndParams
    var parse: (PostgreSQL.Node) -> A
    public init(_ query: QueryStringAndParams, parse: @escaping (PostgreSQL.Node) -> A) {
        self.query = query
        self.parse = parse
    }
}

public struct QueryStringAndParams {
    fileprivate var buildSQL: (inout Int) -> String
    public var values: [NodeRepresentable]
    fileprivate init(buildSQL: @escaping (inout Int) -> String, values: [NodeRepresentable] = []) {
        self.buildSQL = buildSQL
        self.values = values
    }

}

extension QueryStringAndParams: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(buildSQL: { _ in value })
    }
}

extension QueryStringAndParams: ExpressibleByStringInterpolation, StringInterpolationProtocol {
    public init(literalCapacity: Int, interpolationCount: Int) {
        self.buildSQL = { _ in "" }
        self.values = []
    }
    
    public var sql: String {
        var start = 0
        return buildSQL(&start)
    }
    
    public typealias StringInterpolation = QueryStringAndParams
    
    public mutating func appendLiteral(_ x: String) {
        let prev = buildSQL
        self.buildSQL = {
            prev(&$0) + x
        }
    }
    
    // todo this could be a protocol "Safe Identifier" or similar
    public mutating func appendInterpolation(_ t: TableName) {
        let prev = buildSQL
        self.buildSQL = {
            prev(&$0) + t.name
        }
    }
    
    public mutating func appendInterpolation(raw x: String) {
        let prev = buildSQL
        self.buildSQL = {
            prev(&$0) + x
        }
    }
    
    public mutating func appendInterpolation(param n: NodeRepresentable) {
        let prev = buildSQL
        buildSQL = { fieldCount in
            let start = prev(&fieldCount)
            fieldCount += 1
            return start + "$\(fieldCount)"
        }
        self.values.append(n)
    }
    
    public init(stringInterpolation: QueryStringAndParams) {
        self = stringInterpolation
    }
}

extension QueryStringAndParams {
    public mutating func append(_ other: QueryStringAndParams) {
        let prev = buildSQL
        buildSQL = { fc in
            let part1 = prev(&fc)
            let part2 = other.buildSQL(&fc)
            return "\(part1) \(part2)"
        }
        values.append(contentsOf: other.values)
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
    
    @available(*, deprecated)
    static func build(parameters: [NodeRepresentable] = [], parse: @escaping (PostgreSQL.Node) -> A, construct: ([String]) -> String) -> Query {
        let placeholders = (0..<(parameters.count)).map { "$\($0 + 1)" }
        let sql = construct(placeholders)
        return Query(.init(buildSQL: { x in
            x += placeholders.count
            return sql
        }, values: parameters), parse: parse)
    }
    
    public func appending(_ part: QueryStringAndParams) -> Query<A> {
        return Query(query.appending(part), parse: parse)
    }
}

