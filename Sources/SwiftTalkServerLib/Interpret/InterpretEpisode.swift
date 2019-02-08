//
//  Episode.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import Promise
import Database
import WebServer


extension Route.EpisodeR {
    func interpret<I: ResponseRequiringEnvironment>(id: Id<Episode>) throws -> I where I.Env == STRequestEnvironment {
        return .withSession {
            try self.interpret(id: id, session: $0)
        }
    }
    
    private func interpret<I: ResponseRequiringEnvironment>(id: Id<Episode>, session: Session?) throws -> I where I.Env == STRequestEnvironment {
        guard let ep = Episode.all.findEpisode(with: id, scopedFor: session?.user.data) else {
            return .write(html: errorView("No such episode"), status: .notFound)
        }
        
        switch self {
        
        case .view(let playPosition):
            let scoped = Episode.all.scoped(for: session?.user.data)
            // todo: we could have downloadStatus(for:)
            return .query(session?.user.downloads, or: []) { downloads in
                let status = session?.downloadStatus(for: ep, downloads: downloads)
                return scoped.withProgress(for: session?.user.id) { allEpisodes in
                    let featuredEpisodes = Array(allEpisodes.filter { $0.episode != ep }.prefix(8))
                    let position = playPosition ?? allEpisodes.first { $0.episode == ep }?.progress
                    return .write(html: ep.show(playPosition: position, downloadStatus: status ?? .notSubscribed, otherEpisodes: featuredEpisodes))
                }
            }
        
        case .download:
            return .requireSession { s in
                return .onCompleteOrCatch(promise: vimeo.downloadURL(for: ep.vimeoId).promise) { downloadURL in
                    guard let result = downloadURL, let url = result else { return .redirect(to: .episode(ep.id, .view(playPosition: nil))) }
                    return .query(s.user.downloads) { (downloads: [Row<DownloadData>]) in
                        switch s.downloadStatus(for: ep, downloads: downloads) {
                        case .reDownload:
                            return .redirect(path: url.absoluteString, headers: [:])
                        case .canDownload:
                            return .query(DownloadData(user: s.user.id, episode: ep.number).insert) { _ in
                                return .redirect(path: url.absoluteString, headers: [:])
                            }
                        default:
                            return .redirect(to: .episode(ep.id, .view(playPosition: nil))) // just redirect back to episode page if somebody tries this without download credits
                        }
                    }
                }
            }
        
        case .playProgress:
            return .withSession { sess in
                guard let s = sess else { return .write("", status: .ok) }
                return .verifiedPost { body in
                    if let progress = body["progress"].flatMap(Int.init) {
                        let data = PlayProgressData.init(userId: s.user.id, episodeNumber: ep.number, progress: progress, furthestWatched: progress)
                        return .query(data.insertOrUpdate(uniqueKey: "user_id, episode_number")) { _ in
                            return .write("", status: .ok)
                        }
                    }
                    return .write("", status: .ok)
                }
            }
            
        }
    }
}

