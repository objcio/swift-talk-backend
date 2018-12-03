//
//  Model.swift
//  Bits
//
//  Created by Chris Eidhof on 06.08.18.
//

import Foundation
import CommonMark


struct Id<A>: RawRepresentable, Codable, Equatable, Hashable {
    var rawValue: String
}

struct Collaborator: Codable, Equatable {
    var id: Id<Collaborator>
    var name: String
    var url: URL
    var role: Role
}

enum Role: String, Codable, Equatable, Comparable {
    case host = "host"
    case guestHost = "guest-host"
    case transcript = "transcript"
    case copyEditing = "copy-editing"
    case technicalReview = "technical-review"
    case shooting = "shooting"

    static private let order: [Role] = [.host, .guestHost, .technicalReview, .transcript, .copyEditing, .shooting]

    static func <(lhs: Role, rhs: Role) -> Bool {
        return Role.order.index(of: lhs)! < Role.order.index(of: rhs)!
    }

    
    var name: String {
        switch self {
        case .host:
            return "Host"
        case .guestHost:
            return "Guest Host"
        case .transcript:
            return "Transcript"
        case .copyEditing:
            return "Copy Editing"
        case .technicalReview:
            return "Technical Review"
        case .shooting:
            return "Shooting"
        }
    }
}

struct StaticDate: Codable, Equatable {
    var date: Date?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let isoString = try container.decode(String.self)
        date = DateFormatter.iso8601.date(from: isoString)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let isoString = date.map { DateFormatter.iso8601.string(from: $0) } ?? ""
        try container.encode(isoString)
    }
}

struct Episode: Codable, Equatable {
    var collections: [Id<Collection>]
    var collaborators: [Id<Collaborator>]
    var media_duration: TimeInterval
    var number: Int
    var release_at: StaticDate
    var subscription_only: Bool
    var synopsis: String
    var title: String
    var resources: [Resource]
    var vimeo_id: Int
    var preview_vimeo_id: Int?
    var thumbnail_id: Int
    var updates: [Update]?
}

struct Resource: Codable, Equatable {
    var title: String
    var subtitle: String
    var url: URL
}

struct Update: Codable, Equatable {
    var date: StaticDate
    var text: String
}

extension Update {
    var dateAdded: Date {
        return date.date ?? Date()
    }
}

extension Episode {
    var id: Id<Episode> {
        return Id(rawValue: "S01E\(number)-\(title.asSlug)")
    }
    
    var fullTitle: String {
        guard let p = primaryCollection, p.use_as_title_prefix else { return title }
        return "\(p.title): \(title)"
    }
    
    var releaseAt: Date {
        return release_at.date ?? .distantFuture
    }
    
    var released: Bool {
        return releaseAt < Date()
    }
    
    func posterURL(width: Int, height: Int) -> URL {
        return URL(string: "https://i.vimeocdn.com/video/\(thumbnail_id)_\(width)x\(height).jpg")!
    }

    var theCollections: [Collection] {
        return collections.compactMap { cid in
            Collection.allDict[cid]
        }
    }
    
    var theCollaborators: [Collaborator] {
        return collaborators.compactMap { cid in
            Collaborator.all.first { $0.id == cid }
        }
    }
    
    var guestHosts: [Collaborator] {
        return theCollaborators.filter { $0.role == .guestHost }
    }
    
    var primaryCollection: Collection? {
        return theCollections.first
    }
    
    func title(in coll: Collection) -> String {
        guard let p = primaryCollection, p != coll else { return title }
        return p.title + ": " + title
    }
    
    var transcript: CommonMark.Node? {
        return Transcript.forEpisode(number: number)?.contents
    }
    
    var tableOfContents: [(TimeInterval, title: String)] {
        return Transcript.forEpisode(number: number)?.tableOfContents ?? []
    }

    func canWatch(session: Session?) -> Bool {
        return session.premiumAccess || !subscription_only
    }
}

extension Swift.Collection where Element == Episode {
    func scoped(for user: UserData?) -> [Episode] {
        guard let u = user, u.admin || u.collaborator else { return filter { $0.released } }
        return Array(self)
    }

}

struct Collection: Codable, Equatable {
    var id: Id<Collection>
    var title: String
    var `public`: Bool
    var description: String
    var position: Int
    var new: Bool
    var use_as_title_prefix: Bool
}

extension Collection {
    var artwork: String {
        return "/assets/images/collections/\(title).svg"
    }
    
    func episodes(for user: UserData?) -> [Episode] {
        return allEpisodes.scoped(for: user)
    }
}

extension Sequence where Element == Episode {
    var totalDuration: TimeInterval {
        return lazy.map { $0.media_duration }.reduce(0, +)
    }
}

extension String {
    func scanTimePrefix() -> (minutes: Int, seconds: Int, remainder: String)? {
        let s = Scanner(string: self)
        var minutes: Int = 0
        var seconds: Int = 0
        if s.scanInt(&minutes), s.scanString(":", into: nil), s.scanInt(&seconds) {
            return (minutes, seconds, s.remainder)
        } else {
            return nil
        }
    }
}


struct Transcript {
    var number: Int
    var contents: CommonMark.Node
    var tableOfContents: [(TimeInterval, title: String)]
    
    init?(fileName: String, raw: String) {
        guard let number = Int(fileName.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)) else { return nil }
        self.number = number
        
        // Add timestamp links
        guard let nodes = CommonMark.Node(markdown: raw) else { return nil }
        self.contents = CommonMark.Node(blocks: nodes.elements.deepApply({ (inl: Inline) -> [Inline] in
            guard case let .text(t) = inl else { return [inl] }
            if let (m, s, remainder) = t.scanTimePrefix() {
                let totalSeconds = m * 60 + s
                let pretty = "\(m.padded):\(s.padded)"
                return [Inline.link(children: [.text(text: pretty)], title: "", url: "#\(totalSeconds)"), .text(text: remainder)]
            } else {
                return [inl]
            }
        }))
        
        // Extract table of contents
        var result: [(TimeInterval, title: String)] = []
        var currentTitle: String?
        for el in self.contents.elements {
            switch el {
            case let .heading(text: text, _):
                let strs = text.deep(collect: { (i: Inline) -> [String] in
                    guard case let Inline.text(text: t) = i else { return [] }
                    return [t]
                })
                currentTitle = strs.joined(separator: " ")
            case let .paragraph(text: c) where currentTitle != nil:
                if case let .link(lc, _, _)? = c.first, case let .text(t)? = lc.first, let (minutes, seconds, _) = t.scanTimePrefix() {
                    result.append((TimeInterval(minutes*60 + seconds), title: currentTitle!))
                    currentTitle = nil
                }
            default:
                ()
            }
        }
        self.tableOfContents = result
    }
}

