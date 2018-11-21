//
//  StaticData.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation

final class Static<A> {
    typealias Compute = (_ callback: @escaping (A?) -> ()) -> ()
    private let compute: Compute
    var cached: A?
    init(sync: @escaping () -> A?) {
        self.cached = sync()
        self.compute = { cb in
            cb(sync())
        }
    }
    
    init(async: @escaping Compute) {
        self.cached = nil
        self.compute = async
        flush()
    }
    
    func flush() {
        compute { x in
            self.cached = x
        }
    }
}

struct StaticJSON<A: Codable> {
    let fileName: String
    let process: (A) -> A
    init(fileName: String, process: @escaping (A) -> A = { $0 }) {
        self.fileName = fileName
        self.process = process
    }
    
    func read() -> A? {
        do {
            let d = try Data(contentsOf: URL(fileURLWithPath: fileName))
            let e = try JSONDecoder().decode(A.self, from: d)
            return process(e)
        } catch {
            log(error)
            return nil
        }
    }
    
    func write(_ value: A) throws {
        let d = try JSONEncoder().encode(value)
        try d.write(to: URL(fileURLWithPath: fileName))
    }
}

// todo we could have a struct/func that caches/reads cached JSON data

func loadStaticData<A: StaticLoadable>() -> [A] {
    return tryOrLog { try withConnection { connection in
        guard
            let row = try connection.execute(Row<FileData>.staticData(jsonName: A.jsonName)),
            let result = try? JSONDecoder().decode([A].self, from: row.data.value.data(using: .utf8)!)
            else { return [] }
        return result
    }} ?? []
}

func refreshStaticData<A: StaticLoadable>(_ endpoint: RemoteEndpoint<[A]>, onCompletion: @escaping () -> ()) {
    URLSession.shared.load(endpoint) { result in
        tryOrLog { try withConnection { connection in
            guard
                let r = result,
                let data = try? JSONEncoder().encode(r),
                let json = String(data: data, encoding: .utf8)
                else { return }
            let fd = FileData(repository: github.staticDataRepo, path: A.jsonName, value: json)
            tryOrLog("Error caching \(A.jsonName)") { try connection.execute(fd.insertOrUpdate(uniqueKey: "key")) }
            onCompletion()
        }}
    }
}

extension Static {
    static func fromStaticRepo<A: StaticLoadable>(onRefresh: @escaping ([A]) -> () = { _ in }) -> Static<[A]> {
        return Static<[A]>(async: { cb in
            cb(loadStaticData())
            let ep: RemoteEndpoint<[A]> = github.staticData()
            refreshStaticData(ep) {
                let data: [A] = loadStaticData()
                cb(data)
                onRefresh(data)
            }
        })
    }
    
    static func fromStaticRepo<A: StaticLoadable, B>(onRefresh: @escaping (B) -> () = { _ in }, transform: @escaping ([A]) -> B) -> Static<B> {
        return Static<B>(async: { cb in
            cb(transform(loadStaticData()))
            let ep: RemoteEndpoint<[A]> = github.staticData()
            refreshStaticData(ep) {
                let data: [A] = loadStaticData()
                cb(transform(data))
                onRefresh(transform(data))
            }
        })
    }
}

// Todo: this is a bit of a mess, we could look into this.


fileprivate var flushCollectionEpisodes: (() -> ())? = nil // work around for recursive inits. We should come up with a better solution...

fileprivate let theEpisodes: Static<[Episode]> = Static<[Episode]>.fromStaticRepo(onRefresh: { newEpisodes in
    flushCollectionEpisodes?()
    let unreleased = newEpisodes.filter { $0.releaseAt > Date() }
    for ep in unreleased {
        do {
            let query = try Task.releaseEpisode(number: ep.number).schedule(at: ep.releaseAt)
            try lazyConnection().get().execute(query)
        } catch {
            log(error: "Failed to schedule release task for episode \(ep.number)")
        }
    }
}, transform: { $0.sorted { $0.number > $1.number }})

fileprivate let collections = Static<[Collection]>.fromStaticRepo(onRefresh: { _ in
    flushCollectionEpisodes?()
}, transform: { (colls: [Collection]) in
    colls.filter { !$0.expensive_allEpisodes.isEmpty && $0.public }.sorted(by:  { $0.new && !$1.new || $0.position > $1.position })
})

fileprivate let collectionsDict = Static<[Id<Collection>:Collection]>.fromStaticRepo(transform: { (colls: [Collection]) in
    return Dictionary.init(colls.map { ($0.id, $0) }, uniquingKeysWith: { a, b in a })
})
fileprivate let collaborators: Static<[Collaborator]> = Static<[Collaborator]>.fromStaticRepo()

fileprivate var collectionEpisodes: Static<[Id<Collection>:[Episode]]> = Static(sync: {
    guard let e = theEpisodes.cached, let c = collections.cached else {
        return [:]
    }
    return Dictionary(c.map { c in
        return (c.id, c.expensive_allEpisodes)
    }, uniquingKeysWith: { x, _ in x })
})

extension Collection {
    fileprivate var expensive_allEpisodes: [Episode] {
        return (theEpisodes.cached ?? []).filter { $0.collections.contains(id) }
    }
}

fileprivate func loadTranscripts() -> [Transcript] {
    return tryOrLog { try withConnection { connection in
        let rows = try connection.execute(Row<FileData>.transcripts())
        return rows.compactMap { f in Transcript(fileName: f.data.key, raw: f.data.value) }
    }} ?? []
}

func refreshTranscripts(onCompletion: @escaping () -> ()) {
    github.loadTranscripts.run { results in
        tryOrLog { try withConnection { connection in
            for f in results {
                guard let contents = f.contents else { continue }
                let fd = FileData(repository: f.file.repository, path: f.file.path, value: contents)
                tryOrLog("Error caching \(f.file.url)") { try connection.execute(fd.insertOrUpdate(uniqueKey: "key")) }
            }
            onCompletion()
        }}
    }
}

fileprivate let transcripts: Static<[Transcript]> = Static(async: { cb in
    cb(loadTranscripts())
    refreshTranscripts {
        cb(loadTranscripts())
    }
})

fileprivate let cachedPlanData = StaticJSON<[Plan]>(fileName: "data/plans.json")
fileprivate let plans: Static<[Plan]> = Static(async: { cb in
    cb(cachedPlanData.read())
    URLSession.shared.load(recurly.plans) { value in
        cb(value)
        guard let v = value else { log(error: "Could not load plans"); return }
        tryOrLog("Couldn't write cached plan data") { try cachedPlanData.write(v) }
    }
})


func flushStaticData() {
    theEpisodes.flush()
    collections.flush()
    plans.flush()
    collaborators.flush()
    transcripts.flush()
    collectionEpisodes.flush()
    verifyStaticData()
}

func verifyStaticData() {
    myAssert(Plan.all.count >= 2)
    let episodes = Episode.all
    let colls = Collection.all
    print("going to set flush collection episodes")
    flushCollectionEpisodes = { collectionEpisodes.flush() }
    for e in episodes {
        for c in e.collections {
            assert(colls.contains(where: { $0.id == c }), "\(c) \(e)")
        }
        for c in e.collaborators {
            assert(Collaborator.all.contains(where: { $0.id == c}), "\(c) \(e)")
        }
    }
    myAssert(transcripts.cached != nil)
}

extension Plan {
    static var all: [Plan] { return plans.cached ?? [] }
}
extension Episode {
    static var all: [Episode] { return theEpisodes.cached ?? [] }
}

extension Collection {
    // todo move the transformation into the cached layer...
    static var all: [Collection] { return collections.cached ?? [] }
    static var allDict: [Id<Collection>:Collection] { return collectionsDict.cached ?? [:] }
    var allEpisodes: [Episode] { return collectionEpisodes.cached?[id] ?? [] }
}

extension Collaborator {
    static var all: [Collaborator] { return collaborators.cached ?? [] }
}

extension Transcript {
    static func forEpisode(number: Int) -> Transcript? {
        return (transcripts.cached ?? []).first { $0.number == number }
    }
}
