//
//  StaticData.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation

final class Static<A> {
    typealias Compute = (_ callback: @escaping (A?) -> ()) -> ()
    private var compute: Compute
    fileprivate let observable: Observable<A?>
    
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
        compute { [weak self] x in
            self?.observable.send(x)
        }
    }
}


// Re-computable static sources

fileprivate let episodesSource: Static<[Episode]> = .fromStaticRepo(onRefresh: { newEpisodes in
    for ep in newEpisodes where ep.releaseAt > Date() {
        let query = Task.releaseEpisode(number: ep.number).schedule(at: ep.releaseAt)
        tryOrLog("Failed to schedule release task for episode \(ep.number)") { try lazyConnection().get().execute(query) }
    }
})

fileprivate let collectionsSource: Static<[Collection]> = .fromStaticRepo()

fileprivate let collaboratorsSource: Static<[Collaborator]> = Static<[Collaborator]>.fromStaticRepo()

fileprivate let transcriptsSource: Static<[Transcript]> = Static(async: { cb in
    cb(queryTranscripts())
    refreshTranscripts {
        cb(queryTranscripts())
    }
})

fileprivate let plansSource: Static<[Plan]> = Static(async: { cb in
    let jsonName = "plans.json"
    let initial: [Plan] = loadStaticData(name: jsonName)
    cb(initial)
    URLSession.shared.load(recurly.plans) { value in
        cb(value)
        guard let v = value else { log(error: "Could not load plans from Recurly"); return }
        cacheStaticData(v, name: jsonName)
    }
})

func refreshStaticData() {
    episodesSource.refresh()
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
    return c.filter { !$0.expensive_allEpisodes.isEmpty && $0.public }.sorted(by: { $0.new && !$1.new || $0.position > $1.position })
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



// Public properties

extension Plan {
    static var all: [Plan] { return plans.value }
}

extension Episode {
    static var all: [Episode] { return sortedEpisodes.value }
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

