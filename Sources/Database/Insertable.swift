//
//  Insertable.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import PostgreSQL


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
    public static func parse(_ node: PostgreSQL.Node) -> [Row<Self>] {
        return PostgresNodeDecoder.decode([Row<Self>].self, transformKey: { $0.snakeCased }, node: node)
    }
    
    public static func parseFirst(_ node: PostgreSQL.Node) -> Row<Self>? {
        return self.parse(node).first
    }

    public static func parseEmpty(_ node: PostgreSQL.Node) -> () {
    }
}

fileprivate func parseId(_ node: PostgreSQL.Node) -> UUID {
    return UUID(uuidString: node[0, "id"]!.string!)!
}

extension Insertable {
    public var insert: Query<UUID> {
        return Query("INSERT INTO \(Self.tableName) \(values: fieldValues.fieldsAndValues) RETURNING id", parse: parseId)
    }

    
    public func findOrInsert(uniqueKey: String, value: NodeRepresentable) -> Query<UUID> {
        return Query("""
            WITH inserted AS (
            INSERT INTO \(Self.tableName) \(values: fieldValues.fieldsAndValues)
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
            INSERT INTO \(Self.tableName) \(values: f.fieldsAndValues)
            ON CONFLICT (\(raw: uniqueKey)) DO UPDATE SET \(raw: updates)
            RETURNING id
            """, parse: parseId)
    }
}

