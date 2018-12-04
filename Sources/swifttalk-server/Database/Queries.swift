//
//  Queries.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation
import PostgreSQL

struct Query<A> {
    var query: String
    var values: [NodeRepresentable]
    var parse: (PostgreSQL.Node) -> A
}

extension Query {
    func map<B>(_ transform: @escaping (A) -> B) -> Query<B> {
        return Query<B>(query: query, values: values) { node in
            return transform(self.parse(node))
        }
    }
    
    static func build(parameters: [NodeRepresentable] = [], parse: @escaping (PostgreSQL.Node) -> A, construct: ([String]) -> String) -> Query {
        let placeholders = (0..<(parameters.count)).map { "$\($0 + 1)" }
        let sql = construct(placeholders)
        return Query(query: sql, values: parameters, parse: parse)
    }
    
    func appending(parameters: [NodeRepresentable] = [], construct: ([String]) -> String) -> Query<A> {
        let placeholders = (values.count..<(values.count + parameters.count)).map { "$\($0 + 1)" }
        let sql = construct(placeholders)
        return Query(query: "\(query) \(sql)", values: values + parameters, parse: parse)
    }
}

struct Row<Element: Codable>: Codable {
    var id: UUID
    var data: Element
    
    // For importing

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: CodingKeys.id)
        self.data = try Element(from: decoder)
    }
}

fileprivate func parseId(_ node: PostgreSQL.Node) -> UUID {
    return UUID(uuidString: node[0, "id"]!.string!)!
}

fileprivate func parseEmpty(_ node: PostgreSQL.Node) -> () {
}

fileprivate extension Insertable {
    static func parse(_ node: PostgreSQL.Node) -> [Row<Self>] {
        return PostgresNodeDecoder.decode([Row<Self>].self, transformKey: { $0.snakeCased }, node: node)
    }

    static func parseFirst(_ node: PostgreSQL.Node) -> Row<Self>? {
        return self.parse(node).first
    }
}


extension Row where Element: Insertable {
    static func select(_ id: UUID) -> Query<Row<Element>?> {
        return selectOne.appending(parameters: [id]) { "WHERE id=\($0[0])" }
    }

    static var select: Query<[Row<Element>]> {
        let fields = Element.fieldNames.sqlJoined
        return .build(parse: Element.parse) { _ in
            "SELECT id,\(fields) FROM \(Element.tableName)"
        }
    }
    
    static var selectOne: Query<Row<Element>?> {
        return select.map { $0.first }
    }
    
    static var delete: Query<()> {
        return Query(query: "DELETE FROM \(Element.tableName)", values: [], parse: parseEmpty)
    }
    
    var delete: Query<()> {
        return Query.build(parameters: [id], parse: parseEmpty) { "DELETE FROM \(Element.tableName) WHERE id=\($0[0])" }
    }
}

extension Insertable {
    var insert: Query<UUID> {
        let f = fields
        return .build(parameters: f.values, parse: parseId) {
            "INSERT INTO \(Self.tableName) (\(f.names.sqlJoined)) VALUES (\($0.sqlJoined)) RETURNING id"
        }
    }
    
    func insertFromImport(id: UUID) -> Query<()> {
        let f = fields
        return .build(parameters: f.values + [id], parse: { _ in () }) {
            "INSERT INTO \(Self.tableName) (\(f.names.sqlJoined), id) VALUES (\($0.sqlJoined))"
        }
    }

    func findOrInsert(uniqueKey: String, value: NodeRepresentable) -> Query<UUID> {
        let f = fields
        return Query.build(parameters: f.values, parse: parseId) { """
            WITH inserted AS (
                INSERT INTO \(Self.tableName) (\(f.names.sqlJoined)) VALUES (\($0.sqlJoined))
                ON CONFLICT DO NOTHING
                RETURNING id
            )
            """
        }.appending(parameters: [value]) {
            "SELECT id FROM inserted UNION ALL (SELECT id FROM \(Self.tableName) WHERE \(uniqueKey)=\($0[0]) LIMIT 1);"
        }
    }
    
    func insertOrUpdate(uniqueKey: String) -> Query<UUID> {
        let f = fields
        let updates = f.names.map { "\($0) = EXCLUDED.\($0)" }.sqlJoined
        return .build(parameters: f.values, parse: parseId) { """
            INSERT INTO \(Self.tableName) (\(f.names.sqlJoined)) VALUES (\($0.sqlJoined))
            ON CONFLICT (\(uniqueKey)) DO UPDATE SET \(updates)
            RETURNING id
            """
        }
    }
}

extension Row where Element == FileData {
    static func select(key: String) -> Query<Row<FileData>?> {
        return selectOne.appending(parameters: [key]) { "WHERE key=\($0[0])" }
    }
    
    static func select(repository: String, path: String) -> Query<Row<FileData>?> {
        return select(key: FileData.key(forRepository: repository, path: path))
    }
    
    static func transcripts() -> Query<[Row<FileData>]> {
        return select.appending(parameters: [FileData.keyPrefix(forRepository: github.transcriptsRepo)]) {
            "WHERE key LIKE \($0[0]) || '%'"
        }
    }
    
    static func staticData(jsonName: String) -> Query<Row<FileData>?> {
        let key = FileData.key(forRepository: github.staticDataRepo, path: jsonName)
        return selectOne.appending(parameters: [key]) { "WHERE key=\($0[0])" }
    }
}

extension Row where Element == UserData {
    static func select(githubId id: Int) -> Query<Row<Element>?> {
        return Row<UserData>.selectOne.appending(parameters: [id]) { "WHERE github_uid=\($0[0])" }
    }
    
    static func select(githubLogin login: String) -> Query<Row<Element>?> {
        return Row<UserData>.selectOne.appending(parameters: [login]) { "WHERE github_login=\($0[0])" }
    }

    static func select(sessionId id: UUID) -> Query<Row<Element>?> {
        let fields = UserData.fieldNames.map { "u.\($0)" }.sqlJoined
        return .build(parameters: [id], parse: Element.parseFirst) {
            "SELECT u.id,\(fields) FROM \(UserData.tableName) AS u INNER JOIN \(SessionData.tableName) AS s ON s.user_id = u.id WHERE s.id=\($0[0])"
        }
    }
    
    var masterTeamUser: Query<Row<UserData>?> {
        let fields = UserData.fieldNames.map { "u.\($0)" }.sqlJoined
        return .build(parameters: [id], parse: Element.parseFirst) { """
            SELECT u.id,\(fields) FROM \(UserData.tableName) AS u
            INNER JOIN \(TeamMemberData.tableName) AS t ON t.user_id = u.id
            WHERE t.team_member_id=\($0[0])
            """
        }
    }
    
    var downloads: Query<[Row<DownloadData>]> {
        return Row<DownloadData>.select.appending(parameters: [id]) { "WHERE user_id=\($0[0])" }
    }
    
    var teamMembers: Query<[Row<UserData>]> {
        let fields = UserData.fieldNames.map { "u.\($0)" }.sqlJoined
        return .build(parameters: [id], parse: Element.parse) { """
            SELECT u.id,\(fields) FROM \(UserData.tableName) AS u
            INNER JOIN \(TeamMemberData.tableName) AS t ON t.team_member_id = u.id
            WHERE t.user_id=\($0[0])
            """
        }
    }
    
    func deleteSession(_ sessionId: UUID) -> Query<()> {
        return Row<SessionData>.delete.appending(parameters: [id, sessionId]) { "WHERE user_id=\($0[0]) AND id=\($0[1])" }
    }
    
    func changeSubscriptionStatus(_ subscribed: Bool) -> Query<()> {
        return .build(parameters: [subscribed, id], parse: parseEmpty) { "UPDATE users SET subscriber=\($0[0]) WHERE id=\($0[1])" }
    }
    
    func deleteTeamMember(_ teamMemberId: UUID) -> Query<()> {
        return Row<TeamMemberData>.delete.appending(parameters: [self.id, teamMemberId]) {
            "WHERE user_id=\($0[0]) AND team_member_id=\($0[1])"
        }
    }
}

extension Row where Element == TaskData {
    static var dueTasks: Query<[Row<TaskData>]> {
        return Row<TaskData>.select.appending() { _ in "WHERE date < LOCALTIMESTAMP ORDER BY date ASC" }
    }
}

extension Row where Element: Insertable {
    func update() -> Query<()> {
        let f = data.fields
        return Query.build(parameters: f.values, parse: parseEmpty) {
            "UPDATE \(Element.tableName) SET \(zip(f.names, $0).map { "\($0.0)=\($0.1)" }.sqlJoined)"
        }.appending(parameters: [id]) { "WHERE id=\($0[0])" }
    }
}

extension Row where Element == PlayProgressData {
    static func sortedDesc(for userId: UUID) -> Query<[Row<PlayProgressData>]> {
        return Row<PlayProgressData>.select.appending(parameters: [userId]) { "WHERE user_id=\($0[0]) ORDER BY episode_number DESC" }
    }
}
