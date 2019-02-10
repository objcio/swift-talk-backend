//
//  Interpret.swift
//  Bits
//
//  Created by Chris Eidhof on 24.08.18.
//

import Foundation
import Database
import WebServer


extension Swift.Collection where Element == Episode {
    func withProgress<I: STResponse>(for id: UUID?, _ cont: @escaping ([EpisodeWithProgress]) -> I) -> I {
        guard let userId = id else { return cont(map { EpisodeWithProgress(episode: $0, progress: nil )}) }
        return .query(Row<PlayProgressData>.sortedDesc(for: userId).map { results in
            let progresses = results.map { $0.data }
            return self.map { episode in
            // todo this is (n*m), we should use the fact that `progresses` is sorted!
            EpisodeWithProgress(episode: episode, progress: progresses.first { $0.episodeNumber == episode.number }?.progress)
            }
        }, cont)
    }
}

typealias STResponse = ResponseRequiringEnvironment & FailableResponse

extension Route {
    func interpret<I: STResponse>() throws -> I where I.Env == STRequestEnvironment {
        switch self {

        case .subscription(let s):
            return try s.interpret()
            
        case .account(let action):
            return try action.interpret()
            
        case .gift(let g):
          return try g.interpret()
            
        case let .episode(id, action):
          return try action.interpret(id: id)
            
        case let .login(l):
          return try l.interpret()
            
        case let .signup(s):
          return try s.interpret()

        case let .webhook(hook):
          return try hook.interpret()

        case .home:
            return .withSession { session in
                let scoped = Episode.all.scoped(for: session?.user.data)
                return scoped.withProgress(for: session?.user.id) { .write(html: renderHome(episodes: $0)) }
            }
            
        case .episodes:
            return .withSession { session in
                let scoped = Episode.all.scoped(for: session?.user.data)
                return scoped.withProgress(for: session?.user.id,  { .write(html: index($0)) })
            }
            
        case .collections:
            return .withSession { session in
                .write(html: index(Collection.all.filter { !$0.episodes(for: session?.user.data).isEmpty }))
            }

        case .collection(let name):
            guard let coll = Collection.all.first(where: { $0.id == name }) else {
                return .write(html: errorView("No such collection"), status: .notFound)
            }
            return .withSession { session in
                return coll.episodes(for: session?.user.data).withProgress(for: session?.user.id) {
                    .write(html: coll.show(episodes: $0))
                }
            }
            
        case .sitemap:
            return .write(Route.siteMap)
            
        case .rssFeed:
            return .write(rss: Episode.all.released.rssView)
            
            
        case .episodesJSON:
            return .write(json: episodesJSONView())
            
        case .collectionsJSON:
            return .write(json: collectionsJSONView())
            
        case let .staticFile(path: p):
            let name = p.map { $0.removingPercentEncoding ?? "" }.joined(separator: "/")
            if let n = assets.hashToFile[name] {
                return .writeFile(path: n, maxAge: 31536000)
            } else {
            	return .writeFile(path: name)
            }
            
        case .error:
            return .write(html: errorView("Not found"), status: .notFound)
            
        }
    }
}

