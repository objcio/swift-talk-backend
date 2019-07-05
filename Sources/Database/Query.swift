//
//  Query.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import LibPQ

public struct Query<A> {
    public var query: String
    public var values: [Param]
    var parse: (QueryResult) -> A
}

extension Query {
    public func map<B>(_ transform: @escaping (A) -> B) -> Query<B> {
        return Query<B>(query: query, values: values) { node in
            return transform(self.parse(node))
        }
    }
    
    public static func build(parameters: [Param] = [], parse: @escaping (QueryResult) -> A, construct: ([String]) -> String) -> Query {
        let placeholders = (0..<(parameters.count)).map { "$\($0 + 1)" }
        let sql = construct(placeholders)
        return Query(query: sql, values: parameters, parse: parse)
    }
    
    public func appending(parameters: [Param] = [], construct: ([String]) -> String) -> Query<A> {
        let placeholders = (values.count..<(values.count + parameters.count)).map { "$\($0 + 1)" }
        let sql = construct(placeholders)
        return Query(query: "\(query) \(sql)", values: values + parameters, parse: parse)
    }
}

