//
//  Insertable.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import PostgreSQL


public protocol Insertable: Codable {
    static var tableName: String { get }
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
        let f = fieldValues
        return .build(parameters: f.values, parse: parseId) {
            "INSERT INTO \(Self.tableName) (\(f.fieldList)) VALUES (\($0.sqlJoined)) RETURNING id"
        }
    }
    
    public func insertFromImport(id: UUID) -> Query<()> {
        let f = fieldValues
        return .build(parameters: f.values + [id], parse: { _ in () }) {
            "INSERT INTO \(Self.tableName) (\(f.fieldList), id) VALUES (\($0.sqlJoined))"
        }
    }
    
    public func findOrInsert(uniqueKey: String, value: NodeRepresentable) -> Query<UUID> {
        let f = fieldValues
        return Query.build(parameters: f.values, parse: parseId) { """
            WITH inserted AS (
            INSERT INTO \(Self.tableName) (\(f.fieldList)) VALUES (\($0.sqlJoined))
            ON CONFLICT DO NOTHING
            RETURNING id
            )
            """
            }.appending(parameters: [value]) {
                "SELECT id FROM inserted UNION ALL (SELECT id FROM \(Self.tableName) WHERE \(uniqueKey)=\($0[0]) LIMIT 1);"
        }
    }
    
    public func insertOrUpdate(uniqueKey: String) -> Query<UUID> {
        let f = fieldValues
        let updates = f.fields.map { "\($0) = EXCLUDED.\($0)" }.sqlJoined
        return .build(parameters: f.values, parse: parseId) { """
            INSERT INTO \(Self.tableName) (\(f.fieldList)) VALUES (\($0.sqlJoined))
            ON CONFLICT (\(uniqueKey)) DO UPDATE SET \(updates)
            RETURNING id
            """
        }
    }
}

