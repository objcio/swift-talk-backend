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

struct FileData: Codable, Insertable {
    var key: String
    var value: String
    
    static let tableName: String = "files"
}

extension FileData {
    init(repository: String, path: String, value: String) {
        self.init(key: FileData.key(forRepository: repository, path: path), value: value)
    }
    
    static func key(forRepository repository: String, path: String) -> String {
        return "\(repository)::\(path)"
    }
}

struct SessionData: Codable, Insertable {
    var userId: UUID
    var createdAt: Date
    var updatedAt: Date
    
    init(userId: UUID) {
        self.userId = userId
        self.createdAt = Date()
        self.updatedAt = self.createdAt
    }

    static let tableName: String = "sessions"
}

struct DownloadData: Codable, Insertable {
    var userId: UUID
    var episodeId: UUID
    var createdAt: Date
    init(user: UUID, episode: UUID) {
        self.userId = user
        self.episodeId = episode
        self.createdAt = Date()
    }
    
    static let tableName: String = "downloads"
}

struct UserData: Codable, Insertable {
    var email: String
    var githubUID: Int
    var githubLogin: String
    var githubToken: String
    var avatarURL: String
    var admin: Bool = false
    var name: String
    var rememberCreatedAt: Date
    var createdAt: Date
    var updatedAt: Date
    var recurlyHostedLoginToken: String?
    var paymentMethodId: UUID?
    var lastReconciledAt: Date?
    var collaborator: Bool = false
    var downloadCredits: Int = 0
    var subscriber: Bool = false
    var confirmedNameAndEmail: Bool = false
    
    init(email: String, githubUID: Int, githubLogin: String, githubToken: String, avatarURL: String, name: String) {
        self.email = email
        self.githubUID = githubUID
        self.githubLogin = githubLogin
        self.githubToken = githubToken
        self.avatarURL = avatarURL
        self.name = name
        let now = Date()
        rememberCreatedAt = now
        updatedAt = now
        createdAt = now
        collaborator = false
        downloadCredits = 0
    }
    
    static let tableName: String = "users"
}

extension UserData {
    var premiumAccess: Bool {
        return admin || collaborator || subscriber
    }
    
    func validate() -> [ValidationError] {
        var result: [(String,String)] = []
        if !email.contains("@") {
            result.append(("email", "Invalid email address"))
        }
        if name.isEmpty {
            result.append(("name", "Name isn't empty"))
        }
        return result
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

extension Row where Element: Insertable {
    static func select(_ id: UUID) -> Query<Row<Element>?> {
        let fields = Element.fieldNames.joined(separator: ",")
        let query = "SELECT id,\(fields) FROM \(Element.tableName) WHERE id = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
            return result.first
        })
    }
}

extension Row where Element: Insertable {
    static func select(where conditions: [String: NodeRepresentable]) -> Query<Row<Element>?> {
        let fields = Element.fieldNames.joined(separator: ",")
        let c = conditions.array
        let values = c.map { $0.1 }
        let conditions = c.enumerated().map { idx, p in "\(p.0) = $\(idx + 1)" }.joined(separator: ",")
        let query = "SELECT id,\(fields) FROM \(Element.tableName) WHERE \(conditions);"
        return Query(query: query, values: values, parse: { node in
            let result = PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
            return result.first
        })
    }
}

extension Row where Element == FileData {
    static func select(key: String) -> Query<Row<FileData>?> {
        return select(where: ["key": key])
    }
    
    static func select(repository: String, path: String) -> Query<Row<FileData>?> {
        return select(key: FileData.key(forRepository: repository, path: path))
    }
}

extension Row where Element == UserData {
    static func select(githubId id: Int) -> Query<Row<Element>?> {
        let fields = UserData.fieldNames.joined(separator: ",")
        let query = "SELECT id,\(fields) FROM \(UserData.tableName) WHERE github_uid = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
            return result.first
        })
    }
    
    static func select(sessionId id: UUID) -> Query<Row<Element>?> {
        let fields = UserData.fieldNames.map { "u.\($0)" }.joined(separator: ",")
        let query = "SELECT u.id,\(fields) FROM \(UserData.tableName) AS u INNER JOIN \(SessionData.tableName) AS s ON s.user_id = u.id WHERE s.id = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<Element>].self, transformKey: { $0.snakeCased }, node: node)
            return result.first
        })
    }
    
    var downloads: Query<[Row<DownloadData>]> {
        let fields = DownloadData.fieldNames.map { "d.\($0)" }.joined(separator: ", ")
        let query = "SELECT d.id, \(fields) FROM \(DownloadData.tableName) AS d WHERE d.user_id = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<DownloadData>].self, transformKey: { $0.snakeCased }, node: node)
            return result
        })
    }
    
    func downloadStatus(for episode: Episode, downloads: [Row<DownloadData>]) -> Episode.DownloadStatus {
        guard data.subscriber else { return .notSubscribed }
        if downloads.contains(where: { $0.id.uuidString == episode.id.rawValue }) {
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


