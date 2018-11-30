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
}

struct Row<Element: Codable>: Codable {
    var id: UUID
    var data: Element
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: CodingKeys.id)
        self.data = try Element(from: decoder)
    }
}

enum QueryCondition {
    case equal(key: String, value: NodeRepresentable)
    case startsWith(key: String, value: NodeRepresentable)
}

extension QueryCondition {
    var value: NodeRepresentable {
        switch self {
        case let .equal(_, v): return v
        case let .startsWith(_, v): return v
        }
    }
    
    func condition(placeholder: Int) -> String {
        switch self {
        case let .equal(k, _): return "\(k) = $\(placeholder)"
        case let .startsWith(k, _): return "\(k) LIKE $\(placeholder) || '%'"
        }
    }
}

extension Sequence where Element == QueryCondition {
    var conditionsAndValues: (String, [NodeRepresentable]) {
        let arr = array
        let values = arr.map { $0.value }
        let conditions = arr.enumerated().map { idx, c in c.condition(placeholder: idx + 1) }.joined(separator: " AND ")
        return (conditions, values)
    }
}

extension Row where Element: Insertable {
    static func select(_ id: UUID) -> Query<Row<Element>?> {
        return selectOne(where: [.equal(key: "id", value: id)])
    }

    static func select(where conditions: [QueryCondition] = []) -> Query<[Row<Element>]> {
        let fields = Element.fieldNames.joined(separator: ",")
        let (conditions, values) = conditions.conditionsAndValues
        let query = "SELECT id,\(fields) FROM \(Element.tableName) WHERE \(conditions);"
        return Query(query: query, values: values, parse: { node in
            return PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
        })
    }
    
    static func selectOne(where conditions: [QueryCondition] = []) -> Query<Row<Element>?> {
        return select(where: conditions).map { $0.first }
    }
    
    static func delete(where conditions: [QueryCondition]) -> Query<()> {
        let (conditions, values) = conditions.conditionsAndValues
        let query = "DELETE FROM \(Element.tableName) WHERE \(conditions);"
        return Query(query: query, values: values, parse: { _ in })
    }
    
    var delete: Query<()> {
        return Query(query: "DELETE FROM \(Element.tableName) WHERE id=$1", values: [id], parse: { _ in })
    }
}

extension Insertable {
    var insert: Query<UUID> {
        let fields = fieldNamesAndValues
        let names = fields.map { $0.0 }.joined(separator: ",")
        let values = fields.map { $0.1 }
        let placeholders = (1...fields.count).map { "$\($0)" }.joined(separator: ",")
        let query = "INSERT INTO \(Self.tableName) (\(names)) VALUES (\(placeholders)) RETURNING id"
        return Query(query: query, values: values, parse: { node in
            return UUID(uuidString: node[0, "id"]!.string!)!
        })
    }
    
    func findOrInsert(uniqueKey: String, value: NodeRepresentable) -> Query<UUID> {
        let fields = fieldNamesAndValues
        let names = fields.map { $0.0 }.joined(separator: ",")
        let values = fields.map { $0.1 }
        let placeholders = (1...fields.count).map { "$\($0)" }.joined(separator: ",")
        let query = """
        WITH inserted AS (
            INSERT INTO \(Self.tableName) (\(names)) VALUES (\(placeholders))
            ON CONFLICT DO NOTHING
            RETURNING id
        )
        SELECT id FROM inserted UNION ALL (SELECT id FROM \(Self.tableName) WHERE \(uniqueKey)=$\(fields.count+1) LIMIT 1);
        """
        return Query(query: query, values: values + [value], parse: { node in
            return UUID(uuidString: node[0, "id"]!.string!)!
        })
    }
    
    func insertOrUpdate(uniqueKey: String) -> Query<UUID> {
        let fields = fieldNamesAndValues
        let names = fields.map { $0.0 }.joined(separator: ",")
        let values = fields.map { $0.1 }
        let placeholders = (1...fields.count).map { "$\($0)" }.joined(separator: ",")
        let updates = fields.map { "\($0.0) = EXCLUDED.\($0.0)" }.joined(separator: ",")
        let query = """
        INSERT INTO \(Self.tableName) (\(names)) VALUES (\(placeholders))
        ON CONFLICT (\(uniqueKey)) DO UPDATE SET \(updates)
        RETURNING id;
        """
        return Query(query: query, values: values, parse: { node in
            return UUID(uuidString: node[0, "id"]!.string!)!
        })
    }
}

extension Row where Element == FileData {
    static func select(key: String) -> Query<Row<FileData>?> {
        return selectOne(where: [.equal(key: "key", value: key)])
    }
    
    static func select(repository: String, path: String) -> Query<Row<FileData>?> {
        return select(key: FileData.key(forRepository: repository, path: path))
    }
    
    static func transcripts() -> Query<[Row<FileData>]> {
        return select(where: [.startsWith(key: "key", value: FileData.keyPrefix(forRepository: github.transcriptsRepo))])
    }
    
    static func staticData(jsonName: String) -> Query<Row<FileData>?> {
        return selectOne(where: [.equal(key: "key", value: FileData.key(forRepository: github.staticDataRepo, path: jsonName))])
    }
}

extension Row where Element == UserData {
    static func select(githubId id: Int) -> Query<Row<Element>?> {
        return Row<UserData>.selectOne(where: [.equal(key: "github_uid", value: id)])
    }
    
    static func select(sessionId id: UUID) -> Query<Row<Element>?> {
        let fields = UserData.fieldNames.map { "u.\($0)" }.joined(separator: ",")
        let query = "SELECT u.id,\(fields) FROM \(UserData.tableName) AS u INNER JOIN \(SessionData.tableName) AS s ON s.user_id = u.id WHERE s.id = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
            return result.first
        })
    }
    
    var masterTeamUser: Query<Row<UserData>?> {
        let fields = UserData.fieldNames.map { "u.\($0)" }.joined(separator: ",")
        let query = "SELECT u.id,\(fields) FROM \(UserData.tableName) AS u INNER JOIN \(TeamMemberData.tableName) AS t ON t.user_id = u.id WHERE t.team_member_id = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
            return result.first
        })
    }
    
    var downloads: Query<[Row<DownloadData>]> {
        return Row<DownloadData>.select(where: [.equal(key: "user_id", value: id)])
    }
    
    var teamMembers: Query<[Row<UserData>]> {
        let fields = UserData.fieldNames.map { "u.\($0)" }.joined(separator: ",")
        let query = "SELECT u.id,\(fields) FROM \(UserData.tableName) AS u INNER JOIN \(TeamMemberData.tableName) AS t ON t.team_member_id = u.id WHERE t.user_id = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
            return result
        })
    }
    
    func downloadStatus(for episode: Episode, downloads: [Row<DownloadData>]) -> Episode.DownloadStatus {
        guard data.subscriber || data.admin else { return .notSubscribed }
        if data.admin || downloads.contains(where: { $0.data.episodeNumber == episode.number }) {
            return .reDownload
        } else if data.downloadCredits - downloads.count > 0 {
            return .canDownload(creditsLeft: data.downloadCredits - downloads.count)
        } else {
            return .noCredits
        }
    }

    func deleteSession(_ sessionId: UUID) -> Query<()> {
        return Query(query: "DELETE FROM \(SessionData.tableName) where user_id = $1 AND id = $2", values: [id, sessionId], parse: { _ in })
    }
    
    func changeSubscriptionStatus(_ subscribed: Bool) -> Query<()> {
        return Query(query: "UPDATE users SET subscriber = $1 where id = $2", values: [subscribed, id], parse: { _ in () })
    }
    
    func deleteTeamMember(_ teamMemberId: UUID) -> Query<()> {
        return Row<TeamMemberData>.delete(where: [.equal(key: "user_id", value: self.id), .equal(key: "team_member_id", value: teamMemberId)])
    }
}

extension Row where Element == TaskData {
    static var dueTasks: Query<[Row<TaskData>]> {
        let query = "SELECT * FROM \(Element.tableName) WHERE date < LOCALTIMESTAMP ORDER BY date ASC;"
        return Query(query: query, values: [], parse: { node in
            return PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
        })
    }
}

extension Row where Element: Insertable {
    func update() -> Query<()> {
        let fields = data.fieldNamesAndValues
        let fieldNames = zip(fields, 2...).map { (nameAndValue, idx) in
            return "\(nameAndValue.0) = $\(idx)"
        }.joined(separator: ", ")
        return Query(query: "UPDATE \(Element.tableName) SET \(fieldNames) where id = $1", values: [id] + fields.map { $0.1 }, parse: { _ in () })
    }
}

extension Row where Element == PlayProgressData {
    static func sortedDesc(for userId: UUID) -> Query<[Row<PlayProgressData>]> {
        let query = "SELECT * FROM \(Element.tableName) WHERE user_id=$1 ORDER BY episode_number DESC;"
        return Query(query: query, values: [userId], parse: { node in
            return PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
        })
    }
}
