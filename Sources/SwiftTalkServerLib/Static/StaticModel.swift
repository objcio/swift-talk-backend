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
    
    var id: Id<Collaborator>
    var name: String
    var url: URL
    var role: Role
}

struct Episode: Codable, Equatable {
    var collections: [Id<Collection>]
    var collaborators: [Id<Collaborator>]
    var mediaDuration: TimeInterval
    var number: Int
    var releaseAt: Date
    var subscriptionOnly: Bool
    var synopsis: String
    var title: String
    var resources: [Resource]
    var vimeoId: Int
    var previewVimeoId: Int?
    var thumbnailId: Int
    var updates: [Update]?
}

struct Resource: Codable, Equatable {
    var title: String
    var subtitle: String
    var url: URL
}

struct Update: Codable, Equatable {
    var date: Date
    var text: String
}

extension Episode {
    var seasonAndEpisodeShortcut: String {
        return "S01E\(number)"
    }
    
    var id: Id<Episode> {
        return Id(rawValue: "\(seasonAndEpisodeShortcut)-\(title.asSlug)")
    }
    
    var fullTitle: String {
        guard let p = primaryCollection, p.useAsTitlePrefix else { return title }
        return "\(p.title): \(title)"
    }
    
    var released: Bool {
        return releaseAt < globals.currentDate()
    }
    
    func posterURL(width: Int, height: Int) -> URL {
        return URL(string: "https://i.vimeocdn.com/video/\(thumbnailId)_\(width)x\(height).jpg")!
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
    
    var highlightedTranscript: String? {
        return Transcript.forEpisode(number: number)?.highlighted
    }
    
    var tableOfContents: [(TimeInterval, title: String)] {
        return Transcript.forEpisode(number: number)?.tableOfContents ?? []
    }

    func canWatch(session: Session?) -> Bool {
        return session.premiumAccess || !subscriptionOnly
    }
}

extension Swift.Collection where Element == Episode {
    var released: [Episode] {
        return filter { $0.released }
    }
    
    func scoped(for user: UserData?) -> [Episode] {
        guard let u = user, u.isAdmin || u.isCollaborator else { return released }
        return Array(self)
    }
    
    func findEpisode(with id: Id<Episode>, scopedFor user: UserData?) -> Episode? {
        let eps = scoped(for: user)
        guard let start = id.rawValue.firstIndex(of: "E").map({ id.rawValue.index(after: $0) }) else { return nil }
        let end = id.rawValue.firstIndex(of: "-") ?? id.rawValue.endIndex
        guard end > start else { return nil }
        let number = Int(id.rawValue[start..<end])
        return eps.first { $0.number == number }
    }
}

struct Collection: Codable, Equatable {
    var id: Id<Collection>
    var title: String
    var `public`: Bool
    var description: String
    var position: Int
    var new: Bool
    var useAsTitlePrefix: Bool
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
        return lazy.map { $0.mediaDuration }.reduce(0, +)
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
//    private var contents: CommonMark.Node
    var highlighted: String
    var tableOfContents: [(TimeInterval, title: String)]
    
    init?(fileName: String, raw: String, highlight: Bool = false) {
        guard let number = Int(fileName.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)) else { return nil }
        self.number = number

        
        // Add timestamp links
        guard let nodes = CommonMark.Node(markdown: raw) else { return nil }
        let contents = CommonMark.Node(blocks: nodes.elements.deepApply({ (inl: Inline) -> [Inline] in
            guard case let .text(t) = inl else { return [inl] }
            if let (m, s, remainder) = t.scanTimePrefix() {
                let totalSeconds = m * 60 + s
                let pretty = "\(m.padded):\(s.padded)"
                return [Inline.link(children: [.text(text: pretty)], title: "", url: "#\(totalSeconds)"), .text(text: remainder)]
            } else {
                return [inl]
            }
        }))
        highlighted = highlight ? contents.commonMark.markdownToHighlightedHTML : contents.html
        
        // Extract table of contents
        var result: [(TimeInterval, title: String)] = []
        var currentTitle: String?
        for el in contents.elements {
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

