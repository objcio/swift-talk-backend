//
//  Interpret.swift
//  Bits
//
//  Created by Chris Eidhof on 24.08.18.
//

import Foundation
import PostgreSQL
import NIOHTTP1

extension Swift.Collection where Element == Episode {
    func withProgress<I: Interp>(for id: UUID?, _ cont: @escaping ([EpisodeWithProgress]) -> I) -> I {
        guard let userId = id else { return cont(map { EpisodeWithProgress(episode: $0, progress: nil )}) }
        
        return I.query(Row<PlayProgressData>.sortedDesc(for: userId).map { results in
        	let progresses = results.map { $0.data }
            return self.map { episode in
            // todo this is (n*m), we should use the fact that `progresses` is sorted!
            EpisodeWithProgress(episode: episode, progress: progresses.first { $0.episodeNumber == episode.number }?.progress)
            }
        }, cont)
    }
}

typealias Interp = SwiftTalkInterpreter & HTML & HasSession & HasDatabase

extension Route {
    func interpret<I: Interp>() throws -> I {
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
            return I.withSession { session in
                let scoped = Episode.all.scoped(for: session?.user.data)
                return scoped.withProgress(for: session?.user.id) { .write(renderHome(episodes: $0)) }
            }
            
        case .episodes:
            return I.withSession { session in
                let scoped = Episode.all.scoped(for: session?.user.data)
                return scoped.withProgress(for: session?.user.id,  { I.write(index($0)) })
            }
            
        case .collections:
            return I.withSession { session in
                I.write(index(Collection.all.filter { !$0.episodes(for: session?.user.data).isEmpty }))
            }

        case .collection(let name):
            guard let coll = Collection.all.first(where: { $0.id == name }) else {
                return .write(errorView("No such collection"), status: .notFound)
            }
            return I.withSession { session in
                return coll.episodes(for: session?.user.data).withProgress(for: session?.user.id) {
                    I.write(coll.show(episodes: $0))
                }
            }
            
        case .sitemap:
            return .write(Route.siteMap)
            
        case .rssFeed:
            return I.write(rss: Episode.all.released.rssView)
            
            
        case .episodesJSON:
            return I.write(json: episodesJSONView())
            
        case .collectionsJSON:
            return I.write(json: collectionsJSONView())
            
        case let .staticFile(path: p):
            let name = p.map { $0.removingPercentEncoding ?? "" }.joined(separator: "/")
            if let n = assets.hashToFile[name] {
                return I.writeFile(path: n, maxAge: 31536000)
            } else {
            	return .writeFile(path: name)
            }
            
        case .error:
            return .write(errorView("Not found"), status: .notFound)
            
        }
    }
}

