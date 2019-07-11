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
    public static func select(_ id: UUID) -> Query<Database.Row<Element>?> {
        return selectOne.appending("WHERE id=\(param: id)")
    }
    
    public static var select: Query<[Row<Element>]> {
        let fields = Element.fieldList()
        return Query("SELECT id,\(raw: fields) FROM \(Element.tableName)", parse: Element.parse)
    }
    
    public static var selectOne: Query<Row<Element>?> {
        return select.map { $0.first }
    }
    
    public static var delete: Query<()> {
        return Query("DELETE FROM \(Element.tableName)", parse: Element.parseEmpty)
    }
    
    public var delete: Query<()> {
        return Query("DELETE FROM \(Element.tableName) WHERE id=\(param: id)", parse: Element.parseEmpty)
    }

    public func update() -> Query<()> {
        let f = data.fieldValues.fieldsAndValues
        assert(!f.isEmpty)
        var query = Query("UPDATE \(Element.tableName) SET", parse: Element.parseEmpty)
        query.append("\(raw: f[0].key)=\(param: f[0].value)")
        return f.dropFirst().reduce(query, { (q, kv) in
            q.appending(", \(raw: kv.0)=\(param: kv.1)")
        }).appending("WHERE id=\(param: id)")
    }
}
