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
    
    var validEmail: Bool {
        return email.contains("@") // todo should we really do more than this?
    }
    
    var validName: Bool {
        return !name.isEmpty
    }
}

struct Row<A: Codable>: Codable {
    var id: UUID
    var data: A
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: CodingKeys.id)
        self.data = try A(from: decoder)
    }
}

extension Row where A == UserData {
    static func select(githubId id: Int) -> Query<Row<A>?> {
        let fields = UserData.fieldNames.joined(separator: ",")
        let query = "SELECT id,\(fields) FROM \(UserData.tableName) WHERE github_uid = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<A>].self, transformKey: { $0.snakeCased }, node: node)
            return result.first
        })
    }
    
    static func select(sessionId id: UUID) -> Query<Row<A>?> {
        let fields = UserData.fieldNames.map { "u.\($0)" }.joined(separator: ",")
        let query = "SELECT u.id,\(fields) FROM \(UserData.tableName) AS u INNER JOIN \(SessionData.tableName) AS s ON s.user_id = u.id WHERE s.id = $1"
        return Query(query: query, values: [id], parse: { node in
            let result = PostgresNodeDecoder.decode([Row<A>].self, transformKey: { $0.snakeCased }, node: node)
            return result.first
        })
    }

    func deleteSession(_ sessionId: UUID) -> Query<()> {
        return Query(query: "DELETE FROM \(SessionData.tableName) where user_id = $1 AND id = $2", values: [id, sessionId], parse: { _ in })
    }
    
    func changeSubscriptionStatus(_ subscribed: Bool) -> Query<()> {
        return Query(query: "UPDATE users SET subscriber = $1 where id = $2", values: [subscribed, id], parse: { _ in () })
    }
}

extension Row where A: Insertable {
    func update() -> Query<()> {
        let fields = data.fieldNamesAndValues
        let fieldNames = zip(fields, 2...).map { (nameAndValue, idx) in
            return "\(nameAndValue.0) = $\(idx)"
        }.joined(separator: ", ")
        return Query(query: "UPDATE \(A.tableName) SET \(fieldNames) where id = $1", values: [id] + fields.map { $0.1 }, parse: { _ in () })
    }
}


