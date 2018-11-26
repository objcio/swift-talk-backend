//
//  DatabaseModel.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 26-11-2018.
//

import Foundation


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
        return "\(keyPrefix(forRepository: repository))\(path)"
    }
    
    static func keyPrefix(forRepository repository: String) -> String {
        return "\(repository)::"
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
    var episodeNumber: Int
    var createdAt: Date
    init(user: UUID, episode: Int) {
        self.userId = user
        self.episodeNumber = episode
        self.createdAt = Date()
    }
    
    static let tableName: String = "downloads"
}

struct CSRFToken: Codable, Equatable, Hashable {
    var value: UUID
    init(_ uuid: UUID) {
        self.value = uuid
    }
    init(from decoder: Decoder) throws {
        self.init(try UUID(from: decoder))
    }
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
    var stringValue: String {
        return value.uuidString
    }
}

struct UserData: Codable, Insertable {
    var email: String
    var githubUID: Int
    var githubLogin: String
    var githubToken: String?
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
    var csrf: CSRFToken
    
    init(email: String, githubUID: Int, githubLogin: String, githubToken: String? = nil, avatarURL: String, name: String) {
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
        csrf = CSRFToken(UUID())
    }
    
    static let tableName: String = "users"
}

struct TeamMemberData: Codable, Insertable {
    var userId: UUID
    var teamMemberId: UUID
    
    static let tableName: String = "team_members"
}

extension UserData {
    var premiumAccess: Bool {
        return admin || collaborator || subscriber
    }
    
    static let emailRegex = try! NSRegularExpression(pattern: "^[^@]+@(?:[^@.]+?\\.)+.{2,}$", options: [.caseInsensitive])
    
    func validate() -> [ValidationError] {
        var result: [(String,String)] = []
        if UserData.emailRegex.matches(in: email, options: [], range: NSRange(email.startIndex..<email.endIndex, in: email)).isEmpty {
            result.append(("email", "Invalid email address"))
        }
        if name.isEmpty {
            result.append(("name", "Name cannot be empty"))
        }
        return result
    }
    
}
