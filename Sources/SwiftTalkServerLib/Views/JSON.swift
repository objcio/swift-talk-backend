//
//  JSON.swift
//  swifttalk-server
//
//  Created by Chris Eidhof on 06.12.18.
//

import Foundation
import Model

extension EpisodeView {
    init(_ e: Episode) {
        self = EpisodeView(
            id: e.id.rawValue,
            number: e.number,
            title: e.title,
            synopsis: e.synopsis,
            url: Route.episode(e.id, .view(playPosition: nil)).url,
            small_poster_url: e.posterURL(width: 590, height: 270),
            poster_url: e.posterURL(),
            media_duration: Int(e.mediaDuration),
            released_at: e.releaseAt,
            collection: e.primaryCollection?.id.rawValue ?? "",
            subscription_only: e.subscriptionOnly,
            hls_url: e.canWatch(session: nil) ? e.video?.hlsURL : nil,
            preview_url: e.previewVideo?.hlsURL)
    }
}

extension CollectionView {
    init(_ c: Collection) {
        let artwork = Artwork(
            svg: env.baseURL.appendingPathComponent(c.artwork),
            png: env.baseURL.appendingPathComponent(c.artworkPNG)
        )
        let eps = c.allEpisodes.released
        self = CollectionView(id: c.id.rawValue, title: c.title, url: Route.collection(c.id).url, artwork: artwork, episodes_count: eps.count, total_duration: Int(eps.totalDuration), description: c.description, new: c.new)
    }
}

extension EpisodeDetails {
    init?(_ e: Episode, session: Session?) {
        guard e.canWatch(session: session) else { return nil }
        self = EpisodeDetails(id: e.id.rawValue, hls_url: e.video?.hlsURL, toc: e.tableOfContents.map { TocItem(position: $0.0, title: $0.1)}, transcript: Markdown(Transcript.forEpisode(number: e.number)?.raw ?? ""))
    }
}

func episodesJSONView() -> Data {
    let eps = Episode.all.released.map(EpisodeView.init)
    return (try? encoder.encode(eps)) ?? Data()
}

func collectionsJSONView() -> Data {
    let colls = Collection.all.filter { $0.public }.map(CollectionView.init)
    return (try? encoder.encode(colls)) ?? Data()
}

func episodeDetailJSONView(_ episode: Episode, _ session: Session?) -> Data {
    let details = EpisodeDetails(episode, session: session)
    return (try? encoder.encode(details)) ?? Data()
}
