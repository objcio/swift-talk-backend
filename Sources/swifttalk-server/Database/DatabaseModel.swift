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

struct Gift: Codable, Insertable {
    var gifterEmail: String
    var gifterName: String
    var gifteeEmail: String
    var gifteeName: String
    var sendAt: Date
    var message: String
    var gifterUserId: UUID?
    var gifteeUserId: UUID?
    var subscriptionId: String?
    static let tableName: String = "gifts"
    
    func validate() -> [ValidationError] {
        var result: [(String,String)] = []
        if gifterName.isEmpty {
            result.append(("name", "Your name can't be empty."))
        }
        if !gifterEmail.isValidEmail {
            result.append(("gifter_email", "Your email address is invalid."))
        }
        if !gifteeEmail.isValidEmail {
            result.append(("giftee_email", "Their email address is invalid."))
        }
        if sendAt < Date() && !sendAt.isToday {
            result.append(("send_at", "The date cannot be in the past."))
        }
        // todo check send-at date
        return result
    }
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
    var githubUID: Int?
    var githubLogin: String?
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
    var downloadCreditsOffset: Int = 0
    var subscriber: Bool = false
    var canceled: Bool = false
    var confirmedNameAndEmail: Bool = false
    var csrf: CSRFToken

    
    init(email: String, githubUID: Int? = nil, githubLogin: String? = nil, githubToken: String? = nil, avatarURL: String, name: String, createdAt: Date? = nil, rememberCreatedAt: Date? = nil, updatedAt: Date? = nil, collaborator: Bool = false, downloadCredits: Int = 0, canceled: Bool = false, confirmedNameAndEmail: Bool = false) {
        self.email = email
        self.githubUID = githubUID
        self.githubLogin = githubLogin
        self.githubToken = githubToken
        self.avatarURL = avatarURL
        self.name = name
        let now = Date()
        self.rememberCreatedAt = rememberCreatedAt ?? now
        self.updatedAt = updatedAt ?? now
        self.createdAt = createdAt ?? now
        self.collaborator = collaborator
        self.downloadCredits = downloadCredits
        csrf = CSRFToken(UUID())
        self.canceled = canceled
        self.confirmedNameAndEmail = confirmedNameAndEmail
    }
    
    static let tableName: String = "users"
}

struct TeamMemberData: Codable, Insertable {
    var userId: UUID
    var teamMemberId: UUID
    
    static let tableName: String = "team_members"
}

fileprivate let emailRegex = try! NSRegularExpression(pattern: "^[^@]+@(?:[^@.]+?\\.)+.{2,}$", options: [.caseInsensitive])

extension String {
    var isValidEmail: Bool {
        return !emailRegex.matches(in: self, options: [], range: NSRange(startIndex..<endIndex, in: self)).isEmpty
    }
}

extension UserData {
    var premiumAccess: Bool {
        return admin || collaborator || subscriber
    }
    
    func validate() -> [ValidationError] {
        var result: [(String,String)] = []
        if !email.isValidEmail {
            result.append(("email", "Invalid email address"))
        }
        if name.isEmpty {
            result.append(("name", "Name cannot be empty"))
        }
        return result
    }

    func downloadStatus(for episode: Episode, downloads: [Row<DownloadData>]) -> Episode.DownloadStatus {
        guard subscriber || admin else { return .notSubscribed }
        let creditsLeft = (downloadCredits + downloadCreditsOffset) - downloads.count
        if admin || downloads.contains(where: { $0.data.episodeNumber == episode.number }) {
            return .reDownload
        } else if creditsLeft > 0 {
            return .canDownload(creditsLeft: creditsLeft)
        } else {
            return .noCredits
        }
    }
}

struct PlayProgressData {
    var userId: UUID
    var episodeNumber: Int
    var progress: Int
    var furthestWatched: Int
    
    static let tableName = "play_progress"
}

extension PlayProgressData: Insertable { }
