//
//  Insertable.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import LibPQ


public struct TableName {
    let name: String
}

extension TableName: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.name = value
    }
}

public protocol Insertable: Codable {
    static var tableName: TableName { get }
}

extension Insertable {
    public static func parse(_ result: QueryResult) -> [Row<Self>] {
        guard case let .tuples(t) = result else { return [] }
        return PostgresNodeDecoder.decode([Row<Self>].self, transformKey: { $0.snakeCased }, result: t)
    }
    
    public static func parseFirst(_ node: QueryResult) -> Row<Self>? {
        return self.parse(node).first
    }

    public static func parseEmpty(_ node: QueryResult) -> () {
    }
}

fileprivate func parseId(_ result: QueryResult) -> UUID {
    guard case let .tuples(t) = result else { fatalError("Expected a node") }
    return t[0][name: "id"]!
}

extension Insertable {
    public var insert: Query<UUID> {
        return Query("INSERT INTO \(Self.tableName) \(values: fieldValues) RETURNING id", parse: parseId)
    }

    
    public func findOrInsert(uniqueKey: String, value: Param) -> Query<UUID> {
        return Query("""
            WITH inserted AS (
            INSERT INTO \(Self.tableName) \(values: fieldValues)
            ON CONFLICT DO NOTHING
            RETURNING id
            )
        """, parse: parseId).appending(
            "SELECT id FROM inserted UNION ALL (SELECT id FROM \(Self.tableName) WHERE \(raw: uniqueKey)=\(param: value) LIMIT 1);"
        )
    }
    
    public func insertOrUpdate(uniqueKey: String) -> Query<UUID> {
        let f = fieldValues
        let updates = f.fields.map { "\($0) = EXCLUDED.\($0)" }.sqlJoined
        return Query("""
            INSERT INTO \(Self.tableName) \(values: f)
            ON CONFLICT (\(raw: uniqueKey)) DO UPDATE SET \(raw: updates)
            RETURNING id
            """, parse: parseId)
    }
}

