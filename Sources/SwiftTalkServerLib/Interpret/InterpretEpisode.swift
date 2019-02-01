//
//  Episode.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import PostgreSQL
import NIOHTTP1
import Promise

extension Route.EpisodeR {
    func interpret<I: Interp>(id: Id<Episode>) throws -> I {
        return I.withSession {
            try self.interpret2(id: id, session: $0)
        }
    }
    
    private func interpret2<I: Interp>(id: Id<Episode>, session: Session?) throws -> I {
        guard let ep = Episode.all.findEpisode(with: id, scopedFor: session?.user.data) else {
            return .write(errorView("No such episode"), status: .notFound)
        }
        
        switch self {
        
        case .view(let playPosition):
            let scoped = Episode.all.scoped(for: session?.user.data)
            // todo: we could have downloadStatus(for:)
            return I.query(session?.user.downloads, or: []) { downloads in
                let status = session?.downloadStatus(for: ep, downloads: downloads)
                return scoped.withProgress(for: session?.user.id) { allEpisodes in
                    let featuredEpisodes = Array(allEpisodes.filter { $0.episode != ep }.prefix(8))
                    let position = playPosition ?? allEpisodes.first { $0.episode == ep }?.progress
                    return .write(ep.show(playPosition: position, downloadStatus: status ?? .notSubscribed, otherEpisodes: featuredEpisodes))
                }
            }
        
        case .download:
            return I.requireSession { s in
                return .onCompleteOrCatch(promise: vimeo.downloadURL(for: ep.vimeoId).promise) { downloadURL in
                    guard let result = downloadURL, let url = result else { return .redirect(to: .episode(ep.id, .view(playPosition: nil))) }
                    return I.query(s.user.downloads) { (downloads: [Row<DownloadData>]) in
                        switch s.downloadStatus(for: ep, downloads: downloads) {
                        case .reDownload:
                            return .redirect(path: url.absoluteString, headers: [:])
                        case .canDownload:
                            return I.query(DownloadData(user: s.user.id, episode: ep.number).insert) { _ in
                                return .redirect(path: url.absoluteString, headers: [:])
                            }
                        default:
                            return .redirect(to: .episode(ep.id, .view(playPosition: nil))) // just redirect back to episode page if somebody tries this without download credits
                        }
                    }
                }
            }
        
        case .playProgress:
            return I.withSession { sess in
                guard let s = sess else { return I.write("", status: .ok) }
                return I.verifiedPost { body in
                    if let progress = body["progress"].flatMap(Int.init) {
                        let data = PlayProgressData.init(userId: s.user.id, episodeNumber: ep.number, progress: progress, furthestWatched: progress)
                        return I.query(data.insertOrUpdate(uniqueKey: "user_id, episode_number")) { _ in
                            return I.write("", status: .ok)
                        }
                    }
                    return I.write("", status: .ok)
                }
            }
            
        }
    }
}

