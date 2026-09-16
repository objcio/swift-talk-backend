import Foundation

public struct BuildError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

struct Episode: Decodable {
    var number: Int
    var title: String
    var synopsis: String
    var releaseAt: Date
    var mediaDuration: Double
    var vimeoId: Int
    var vimeoHash: String?
    var pictureUrl: String?
    var collections: [String]
    var collaborators: [String]
    var resources: [Resource]
    var updates: [Update]?

    // Match the old router exactly, including its unpadded episode numbers.
    var slug: String { "S01E\(number)-\(title.slug)" }
    var path: String { "/episodes/\(slug)" }
    var posterURL: String? {
        guard let value = pictureUrl else { return nil }
        // An older metadata record lost the punctuation in its HTTPS prefix.
        let normalized = value.hasPrefix("https//i.vimeocdn.com/")
            ? "https:" + value.dropFirst(5)
            : value
        guard let url = URL(string: normalized), url.scheme == "https", url.host != nil else { return nil }
        return url.absoluteString
    }
    var embedURL: String {
        var url = URLComponents(string: "https://player.vimeo.com/video/\(vimeoId)")!
        url.queryItems = [URLQueryItem(name: "dnt", value: "1")]
        if let hash = vimeoHash { url.queryItems?.append(URLQueryItem(name: "h", value: hash)) }
        return url.string!
    }

    func posterURL(width: Int, height: Int) -> String? {
        guard let value = posterURL, var url = URLComponents(string: value) else { return nil }
        url.path = url.path.replacingOccurrences(of: #"_\d+x\d+$"#, with: "_\(width)x\(height)", options: .regularExpression)
        url.query = nil
        return url.string
    }
}

struct Resource: Decodable {
    var title: String
    var subtitle: String
    var url: String
}

struct Update: Decodable {
    var date: Date
    var text: String
}

struct Collection: Decodable, Encodable {
    var id: String
    var title: String
    var description: String
    var position: Int
    var useAsTitlePrefix: Bool
    var path: String { "/collections/\(id)" }
}

struct Collaborator: Decodable {
    var id: String
    var name: String
    var url: String
    var role: String

    var roleName: String { role.replacingOccurrences(of: "-", with: " ").capitalized }
}

struct Content {
    var episodes: [Episode]
    var collections: [Collection]
    var collaborators: [Collaborator]
    var transcripts: [Int: String]

    init(data: URL, transcripts directory: URL, asOf: Date) throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            guard let date = parseDate(value) else { throw BuildError("Invalid release/update date: \(value)") }
            return date
        }
        func load<T: Decodable>(_ name: String) throws -> T {
            do { return try decoder.decode(T.self, from: Data(contentsOf: data.appendingPathComponent(name))) }
            catch { throw BuildError("Unable to read \(name): \(error)") }
        }
        let allEpisodes: [Episode] = try load("episodes.json")
        let allCollections: [Collection] = try load("collections.json")
        collaborators = try load("collaborators.json")
        episodes = allEpisodes.filter { $0.releaseAt <= asOf }.sorted { $0.number > $1.number }
        guard !episodes.isEmpty else { throw BuildError("No released episodes found.") }
        guard Set(allEpisodes.map(\.number)).count == allEpisodes.count else {
            throw BuildError("Duplicate episode numbers in episodes.json.")
        }
        guard Set(allCollections.map(\.id)).count == allCollections.count else {
            throw BuildError("Duplicate collection IDs in collections.json.")
        }
        guard Set(collaborators.map(\.id)).count == collaborators.count else {
            throw BuildError("Duplicate collaborator IDs in collaborators.json.")
        }
        for collection in allCollections {
            guard !collection.id.isEmpty, collection.id == collection.id.slug else {
                throw BuildError("Invalid collection ID: \(collection.id)")
            }
        }
        transcripts = [:]
        for episode in episodes {
            guard episode.number > 0, episode.vimeoId > 0, !episode.title.slug.isEmpty,
                  episode.mediaDuration.isFinite, episode.mediaDuration >= 0 else {
                throw BuildError("Invalid episode metadata for episode \(episode.number).")
            }
            for id in episode.collections where !allCollections.contains(where: { $0.id == id }) {
                throw BuildError("Episode \(episode.number) refers to unknown collection \(id).")
            }
            for id in episode.collaborators where !collaborators.contains(where: { $0.id == id }) {
                throw BuildError("Episode \(episode.number) refers to unknown collaborator \(id).")
            }
            let file = directory.appendingPathComponent("episode\(episode.number).md")
            guard let raw = try? String(contentsOf: file, encoding: .utf8), !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BuildError("Missing or empty transcript: \(file.path)")
            }
            transcripts[episode.number] = raw
        }
        let usedCollections = Set(episodes.flatMap(\.collections))
        collections = allCollections.filter { usedCollections.contains($0.id) }.sorted {
            ($0.position, $0.id) < ($1.position, $1.id)
        }
    }

    func collections(for episode: Episode) -> [Collection] {
        episode.collections.compactMap { id in collections.first { $0.id == id } }
    }

    func fullTitle(_ episode: Episode) -> String {
        guard let collection = collections(for: episode).first, collection.useAsTitlePrefix else { return episode.title }
        return "\(collection.title): \(episode.title)"
    }

    func episodes(in collection: Collection) -> [Episode] {
        let result = episodes.filter { $0.collections.contains(collection.id) }
        return collection.useAsTitlePrefix ? result.reversed() : result
    }
}

func parseDate(_ value: String) -> Date? {
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: value) { return date }
    iso.formatOptions = [.withInternetDateTime]
    if let date = iso.date(from: value) { return date }
    // The existing metadata uses UTC without a zone suffix.
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return formatter.date(from: value)
}

func formattedDate(_ date: Date, format: String = "MMMM d, yyyy") -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = format
    return formatter.string(from: date)
}

func timestamp(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

func hoursAndMinutes(_ seconds: Double) -> String {
    let minutes = Int(seconds / 60)
    return minutes >= 60 ? "\(minutes / 60)h\(String(format: "%02d", minutes % 60))min" : "\(minutes)min"
}

extension String {
    var slug: String {
        components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: "-").lowercased()
    }
    var escaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
