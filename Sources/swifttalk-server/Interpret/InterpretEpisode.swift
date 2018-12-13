//
//  Episode.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import PostgreSQL
import NIOHTTP1

extension Route.EpisodeR {
    func interpret<I: SwiftTalkInterpreter>(id: Id<Episode>, session: Session?, context: Context, connection c: Lazy<Connection>) throws -> I {
        guard let ep = Episode.all.findEpisode(with: id, scopedFor: session?.user.data) else {
            return .write(errorView("No such episode"), status: .notFound)
        }
        switch self {
        case .question:
            return I.form(questionForm(episode: ep, context: context), initial: "", csrf: sharedCSRF, convert: { (str: String) -> Either<Question, [ValidationError]> in
                guard !str.isEmpty else {
                    return .right([(field: "message", message: "Empty question.")])
                }
                return Either.left(Question(userId: session?.user.id, episodeNumber: ep.number, createdAt: Date(), question: str))
            }, onPost: { (question: Question) in
                dump(question)
                try c.get().execute(question.insert)
                return I.write("\(question)")
            })
            
        case .view(let playPosition):
            let downloads = try (session?.user.downloads).map { try c.get().execute($0) } ?? []
            let status = session?.user.data.downloadStatus(for: ep, downloads: downloads) ?? .notSubscribed
            let allEpisodes = try Episode.all.scoped(for: session?.user.data).withProgress(for: session?.user.id, connection: c)
            let featuredEpisodes = Array(allEpisodes.filter { $0.episode != ep }.prefix(8))
            let position = playPosition ?? allEpisodes.first { $0.episode == ep }?.progress
            return .write(ep.show(playPosition: position, downloadStatus: status, otherEpisodes: featuredEpisodes, context: context))
        case .download:
            let s = try session.require()
            return .onCompleteThrows(promise: vimeo.downloadURL(for: ep.vimeoId).promise) { downloadURL in
                guard let result = downloadURL, let url = result else { return .redirect(to: .episode(ep.id, .view(playPosition: nil))) }
                let downloads = try c.get().execute(s.user.downloads)
                switch s.user.data.downloadStatus(for: ep, downloads: downloads) {
                case .reDownload:
                    return .redirect(path: url.absoluteString)
                case .canDownload:
                    try c.get().execute(DownloadData(user: s.user.id, episode: ep.number).insert)
                    return .redirect(path: url.absoluteString)
                default:
                    return .redirect(to: .episode(ep.id, .view(playPosition: nil))) // just redirect back to episode page if somebody tries this without download credits
                }
            }
        case .playProgress:
            guard let s = try? session.require() else { return I.write("", status: .ok)}
            return I.withPostBody(csrf: s.user.data.csrf) { body in
                if let progress = body["progress"].flatMap(Int.init) {
                    let data = PlayProgressData.init(userId: s.user.id, episodeNumber: ep.number, progress: progress, furthestWatched: progress)
                    try c.get().execute(data.insertOrUpdate(uniqueKey: "user_id, episode_number"))
                }
                return I.write("", status: .ok)
            }
        }
    }
}

