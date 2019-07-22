//
//  StaticData.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation
import Base
import Incremental


final class Static<A> {
    typealias Compute = (_ callback: @escaping (A?) -> ()) -> ()
    private var compute: Compute
    fileprivate let observable: Observable<A?>
    private var isRefreshing: Bool = false
    
    init(sync: @escaping () -> A?) {
        observable = Observable(sync())
        self.compute = { cb in
            cb(sync())
        }
    }
    
    init(async: @escaping Compute) {
        observable = Observable(nil)
        self.compute = async
        refresh()
    }
    
    func refresh() {
        if isRefreshing {
            return
        }
        isRefreshing = true
        compute { [weak self] x in
            self?.observable.send(x)
            self?.isRefreshing = false
        }
    }
}


// Re-computable static sources

fileprivate let episodesSource: Static<[Episode]> = .fromStaticRepo(onRefresh: { newEpisodes in
    for ep in newEpisodes where ep.releaseAt > globals.currentDate() {
        let query = Task.releaseEpisode(number: ep.number).schedule(at: ep.releaseAt)
        tryOrLog("Failed to schedule release task for episode \(ep.number)") { try postgres.withConnection { try $0.execute(query) } }
    }
})

fileprivate let collectionsSource: Static<[Collection]> = .fromStaticRepo()

fileprivate let collaboratorsSource: Static<[Collaborator]> = Static<[Collaborator]>.fromStaticRepo()

fileprivate let transcriptsSource: Static<[Transcript]> = Static(async: { cb in
    queryTranscripts(fast: true) { transcripts in
        cb(transcripts)
        refreshTranscripts(knownShas: transcripts.compactMap { $0.sha }) {
            queryTranscripts(cb)
        }
    }
})

fileprivate let plansSource: Static<[Plan]> = Static(async: { cb in
    let jsonName = "plans.json"
    let initial: [Plan] = loadStaticData(name: jsonName)
    cb(initial)
    globals.urlSession.load(recurly.plans) { value in
        cb(try? value.get())
        guard let v = try? value.get() else { log(error: "Could not load plans from Recurly \(value)"); return }
        cacheStaticData(v, name: jsonName)
    }
})

var episodesObserver: Any? = nil

func refreshStaticData() {
    episodesSource.refresh()
    episodesObserver = episodesSource.observable.observe { _ in
        episodesVimeoInfo.refresh()
    }
    collectionsSource.refresh()
    plansSource.refresh()
    collaboratorsSource.refresh()
    transcriptsSource.refresh()
    verifyStaticData()
}


func verifyStaticData() {
    //    myAssert(Plan.all.count >= 2)
    let episodes = Episode.all
    let colls = Collection.all
    let _ = episodes.map { $0.video } // triggers loading of the videos
    for e in episodes {
        for c in e.collections {
            assert(colls.contains(where: { $0.id == c }), "\(c) \(e)")
        }
        for c in e.collaborators {
            assert(Collaborator.all.contains(where: { $0.id == c}), "\(c) \(e.collaborators) \(Collaborator.all)")
        }
    }
    myAssert(transcriptsSource.observable.value != nil)
}


// Observables

fileprivate let sortedEpisodesO: Observable<[Episode]> = episodesSource.observable.map { newEpisodes in
    guard let e = newEpisodes else { return [] }
    return e.sorted { $0.number > $1.number }
}

fileprivate let sortedCollectionsO: Observable<[Collection]> = collectionsSource.observable.map { (colls: [Collection]?) in
    guard let c = colls else { return [] }
    return c.filter { !$0.expensive_allEpisodes.isEmpty && $0.public }.sorted(by: { $0.new && !$1.new || $0.position < $1.position })
}

fileprivate let collectionsDictO: Observable<[Id<Collection>:Collection]> = sortedCollectionsO.map { (colls: [Collection]?) in
    guard let c = colls else { return [:] }
    return Dictionary.init(c.map { ($0.id, $0) }, uniquingKeysWith: { a, b in a })
}

fileprivate var collectionEpisodesO: Observable<[Id<Collection>:[Episode]]> = sortedCollectionsO.flatMap { colls in
    sortedEpisodesO.map { eps in
        return Dictionary(colls.map { c in
            return (c.id, c.expensive_allEpisodes)
        }, uniquingKeysWith: { x, _ in x })
    }
}

fileprivate var collaboratorsO: Observable<[Collaborator]> = collaboratorsSource.observable.map { $0 ?? [] }

fileprivate var transcriptsO: Observable<[Transcript]> = transcriptsSource.observable.map { $0 ?? [] }

fileprivate var plansO: Observable<[Plan]> = plansSource.observable.map { $0 ?? [] }

fileprivate let episodesVimeoInfo = Static<(full: [Id<Episode>:Video], previews: [Id<Episode>:Video])>(async: { cb in
    let e = episodesSource.observable.value ?? []
    let g = DispatchGroup()
    let q = DispatchQueue(label: "Episodes Data")
    var full: [Id<Episode>: Video] = [:]
    var previews: [Id<Episode>: Video] = [:]
    let rateLimit = 100 // requests per second
    var rateLimiter = (0...).lazy.map { Double($0) / (Double(rateLimit)) }.makeIterator()
    
    for i in 0..<e.count {
        let ep = e[i]
        g.enter() // for the full video
        q.asyncAfter(deadline: .now() + rateLimiter.next()!) {
            globals.urlSession.load(vimeo.videoInfo(for: ep.vimeoId)) { res in
                q.async {
                    full[ep.id] = res
                    g.leave()
                }
            }
        }
        q.asyncAfter(deadline: .now() + rateLimiter.next()!) {
            if let p = ep.previewVimeoId {
                g.enter()
                globals.urlSession.load(vimeo.videoInfo(for: p)) { res in
                    q.async {
                        previews[ep.id] = try? res.get()
                        g.leave()
                    }
                }
            }
            
        }
    }
    let q2 = DispatchQueue(label: "Waiting")
    q2.async {
        g.wait()
        print("Done loading video data", full.count, previews.count)
        cb((full, previews))
    }
})


//fileprivate var episodesVimeoInfo: Observable<(full: [Id<Episode>:Video], previews: [Id<Episode>:Video])> = episodesSource.observable.map { newEpisodes in
//
//}

extension Collection {
    fileprivate var expensive_allEpisodes: [Episode] {
        return (episodesSource.observable.value ?? []).filter { $0.collections.contains(id) }
    }
}



// Atomic accessors — only these are used to create the public properties below

extension Observable {
    fileprivate var atomic: Atomic<A> {
        let result = Atomic(value)
        observe { newValue in
            result.mutate { $0 = newValue }
        }
        return result
    }
}

fileprivate var sortedEpisodes = sortedEpisodesO.atomic
fileprivate var sortedCollections = sortedCollectionsO.atomic
fileprivate var collectionsDict = collectionsDictO.atomic
fileprivate var collectionEpisodes = collectionEpisodesO.atomic
fileprivate var collaborators = collaboratorsO.atomic
fileprivate var transcripts = transcriptsO.atomic
fileprivate var plans = plansO.atomic
fileprivate var vimeoInfo = episodesVimeoInfo.observable.atomic

// Public properties

var testPlans: [Plan]? = nil

extension Plan {
    static var all: [Plan] { return testPlans ?? plans.value }
}

extension Episode {
    static var all: [Episode] { return sortedEpisodes.value }
    var video: Video? {
        return vimeoInfo.value?.full[id]
    }
    var previewVideo: Video? {
        return vimeoInfo.value?.previews[id]
    }
}

extension Collection {
    static var all: [Collection] { return sortedCollections.value }
    static var allDict: [Id<Collection>:Collection] { return collectionsDict.value }
    var allEpisodes: [Episode] { return collectionEpisodes.value[id] ?? [] }
}

extension Collaborator {
    static var all: [Collaborator] { return collaborators.value }
}

extension Transcript {
    static func forEpisode(number: Int) -> Transcript? {
        return transcripts.value.first { $0.number == number }
    }
}

