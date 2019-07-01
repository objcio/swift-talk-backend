//
//  JSON.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 06.12.18.
//

import Foundation

struct CollectionView: Codable {
    struct Artwork: Codable {
        var svg: URL
        var png: URL
    }
    var id: String
    var title: String
    var url: URL
    var artwork: Artwork
    var episodes_count: Int
    var total_duration: Int
    var description: String
    var new: Bool
}

struct EpisodeView: Codable {
    var id: String
    var number: Int
    var title: String
    var synopsis: String
    var url: URL
    var small_poster_url: URL
    var poster_url: URL
    var media_duration: Int
    var released_at: Date
    var collection: String // todo: slug<collection>
    var subscription_only: Bool
    var hls_url: URL?
    var preview_url: URL?
}

extension EpisodeView {
    init(_ e: Episode) {
        self.id = e.id.rawValue
        self.number = e.number
        self.title = e.title
        self.synopsis = e.synopsis
        self.url = Route.episode(e.id, .view(playPosition: nil)).url
        self.small_poster_url = e.posterURL(width: 590, height: 270)
        self.poster_url = e.posterURL()
        self.media_duration = Int(e.mediaDuration)
        self.released_at = e.releaseAt
        self.collection = e.primaryCollection?.id.rawValue ?? ""
        self.subscription_only = e.subscriptionOnly
        self.hls_url = e.canWatch(session: nil) ? e.video?.hlsURL : nil // todo: use session?
        self.preview_url = e.previewVideo?.hlsURL
    }
}

extension CollectionView {
    init(_ c: Collection) {
        id = c.id.rawValue
        title = c.title
        url = Route.collection(c.id).url
        artwork = Artwork(
            svg: env.baseURL.appendingPathComponent(c.artwork),
            png: env.baseURL.appendingPathComponent(c.artworkPNG)
        )
        description = c.description
        let eps = c.allEpisodes.released
        episodes_count = eps.count
        total_duration = Int(eps.totalDuration)
        new = c.new
    }
}

private let encoder: JSONEncoder = {
    let r = JSONEncoder()
    r.dateEncodingStrategy = .secondsSince1970
    return r
}()

func episodesJSONView() -> Data {
    let eps = Episode.all.released.map(EpisodeView.init)
    return (try? encoder.encode(eps)) ?? Data()
}

func collectionsJSONView() -> Data {
    let colls = Collection.all.filter { $0.public }.map(CollectionView.init)
    return (try? encoder.encode(colls)) ?? Data()
}
