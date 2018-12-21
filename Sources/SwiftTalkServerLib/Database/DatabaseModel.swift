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

struct GiftData: Codable, Insertable {
    var gifterEmail: String?
    var gifterName: String?
    var gifteeEmail: String
    var gifteeName: String
    var sendAt: Date
    var message: String
    var gifterUserId: UUID?
    var gifteeUserId: UUID?
    var subscriptionId: String?
    var activated: Bool
    var planCode: String
    static let tableName: String = "gifts"
    
    func validate() -> [ValidationError] {
        var result: [(String,String)] = []
        if !gifteeEmail.isValidEmail {
            result.append(("giftee_email", "Their email address is invalid."))
        }
        if sendAt < globals.currentDate() && !sendAt.isToday {
            result.append(("send_at", "The date cannot be in the past."))
        }
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
        self.createdAt = globals.currentDate()
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
        self.createdAt = globals.currentDate()
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
    enum Role: Int, Codable {
        case user = 0
        case collaborator = 1
        case admin = 2
    }
    var email: String
    var githubUID: Int?
    var githubLogin: String?
    var githubToken: String?
    var avatarURL: String
    var role: Role = .user
    var name: String
    var createdAt: Date
    var recurlyHostedLoginToken: String?
    var downloadCredits: Int = 0
    var downloadCreditsOffset: Int = 0
    var subscriber: Bool = false
    var canceled: Bool = false
    var confirmedNameAndEmail: Bool = false
    var csrf: CSRFToken

    
    init(email: String, githubUID: Int? = nil, githubLogin: String? = nil, githubToken: String? = nil, avatarURL: String, name: String, createdAt: Date? = nil, collaborator: Bool = false, downloadCredits: Int = 0, canceled: Bool = false, confirmedNameAndEmail: Bool = false, subscriber: Bool = false) {
        self.email = email
        self.githubUID = githubUID
        self.githubLogin = githubLogin
        self.githubToken = githubToken
        self.avatarURL = avatarURL
        self.name = name
        let now = globals.currentDate()
        self.createdAt = createdAt ?? now
        self.downloadCredits = downloadCredits
        csrf = CSRFToken(UUID())
        self.canceled = canceled
        self.confirmedNameAndEmail = confirmedNameAndEmail
        self.subscriber = subscriber
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
        return role == .admin || role == .collaborator || subscriber
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
    
    var isAdmin: Bool {
        return role == .admin
    }
    
    var isCollaborator: Bool {
        return role == .collaborator
    }

    func downloadStatus(for episode: Episode, downloads: [Row<DownloadData>]) -> Episode.DownloadStatus {
        guard subscriber || isAdmin else { return .notSubscribed }
        let creditsLeft = (downloadCredits + downloadCreditsOffset) - downloads.count
        if isAdmin || downloads.contains(where: { $0.data.episodeNumber == episode.number }) {
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
