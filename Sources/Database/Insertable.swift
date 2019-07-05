//
//  Insertable.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import LibPQ


public protocol Insertable: Codable {
    static var tableName: String { get }
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
    
    public func findOrInsert(uniqueKey: String, value: Param) -> Query<UUID> {
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

