//
//  Queries.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation
import PostgreSQL

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
    static var returning: String? = "id"
    typealias InsertionResult = UUID
    static var parse: (PostgreSQL.Node) throws -> UUID = { node in
        // todo get rid of force-unwraps
        UUID(uuidString: node[0, "id"]!.string!)!
    }
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
    var receiveNewEpisodeEmails: Bool
    var collaborator: Bool = false
    var downloadCredits: Int = 0
    var subscriber: Bool = false
    
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
        receiveNewEpisodeEmails = false
        collaborator = false
        downloadCredits = 0
    }
    
    static let tableName: String = "users"
    static var returning: String? = "id"
    typealias InsertionResult = UUID
    static var parse: (PostgreSQL.Node) throws -> UUID = { node in
        // todo get rid of force-unwraps
        UUID(uuidString: node[0, "id"]!.string!)!
    }
}

extension UserData {
    var premiumAccess: Bool {
        return admin || collaborator || subscriber
    }
}
