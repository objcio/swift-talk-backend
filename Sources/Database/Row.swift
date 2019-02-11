//
//  Row.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation

public struct Row<Element: Codable>: Codable {
    public var id: UUID
    public var data: Element
    
    public init(id: UUID, data: Element) {
        self.id = id
        self.data = data
    }
    
    // For importing
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: CodingKeys.id)
        self.data = try Element(from: decoder)
    }
}

extension Row where Element: Insertable {
    public static func select(_ id: UUID) -> Query<Row<Element>?> {
        return selectOne.appending(parameters: [id]) { "WHERE id=\($0[0])" }
    }
    
    public static var select: Query<[Row<Element>]> {
        let fields = Element.fieldList()
        return .build(parse: Element.parse) { _ in
            "SELECT id,\(fields) FROM \(Element.tableName)"
        }
    }
    
    public static var selectOne: Query<Row<Element>?> {
        return select.map { $0.first }
    }
    
    public static var delete: Query<()> {
        return Query(query: "DELETE FROM \(Element.tableName)", values: [], parse: Element.parseEmpty)
    }
    
    public var delete: Query<()> {
        return Query.build(parameters: [id], parse: Element.parseEmpty) { "DELETE FROM \(Element.tableName) WHERE id=\($0[0])" }
    }

    public func update() -> Query<()> {
        let f = data.fieldValues
        return Query.build(parameters: f.values, parse: Element.parseEmpty) {
            "UPDATE \(Element.tableName) SET \(zip(f.fields, $0).map { "\($0.0)=\($0.1)" }.sqlJoined)"
            }.appending(parameters: [id]) { "WHERE id=\($0[0])" }
    }
}
