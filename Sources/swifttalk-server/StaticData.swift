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
    let observable: Observable<A?>
    
    init(sync: @escaping () -> A?) {
        observable = Observable(sync())
        self.compute = { cb in
            cb(sync())
        }
    }
    
    init(async: @escaping Compute) {
        observable = Observable(nil)
        self.compute = async
        flush()
    }
    
    func flush() {
        compute { [weak self] x in
            self?.observable.send(x)
        }
    }  
}

// Todo we only use this for plans, could do like for the github files (cache it in the db).
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

// todo: chris I think we can make the three functions below a lot simpler...

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
            let initial: [A] = loadStaticData()
            cb(initial)
            print("initial: \(initial.count) - \(A.jsonName)")
            let ep: RemoteEndpoint<[A]> = github.staticData()
            refreshStaticData(ep) {
                print("got new data: \(A.jsonName)")
                let data: [A] = loadStaticData()
                cb(data)
                onRefresh(data)
            }
        })
    }
}

// Todo: this is a bit of a mess, we could look into this.


fileprivate let episodesSource: Static<[Episode]> = .fromStaticRepo(onRefresh: releaseUnreleasedEpisodes)

func releaseUnreleasedEpisodes(newEpisodes: [Episode]) {
    let unreleased = newEpisodes.filter { $0.releaseAt > Date() }
    for ep in unreleased {
        do {
            let query = try Task.releaseEpisode(number: ep.number).schedule(at: ep.releaseAt)
            try lazyConnection().get().execute(query)
        } catch {
            log(error: "Failed to schedule release task for episode \(ep.number)")
        }
    }
}

fileprivate let theEpisodes: Observable<[Episode]> = episodesSource.observable.map { ($0 ?? []).sorted { $0.number > $1.number }}

fileprivate let collectionsSource: Static<[Collection]> = .fromStaticRepo()

fileprivate let collections: Observable<[Collection]> = collectionsSource.observable.map { (colls: [Collection]?) in
    guard let c = colls else { return [] }
    return c.filter { !$0.expensive_allEpisodes.isEmpty && $0.public }.sorted(by:  { $0.new && !$1.new || $0.position > $1.position })
}

fileprivate let collectionsDict: Observable<[Id<Collection>:Collection]> = collections.map { (colls: [Collection]?) in
    guard let c = colls else { return [:] }
    return Dictionary.init(c.map { ($0.id, $0) }, uniquingKeysWith: { a, b in a })
}

fileprivate let collaborators: Static<[Collaborator]> = Static<[Collaborator]>.fromStaticRepo()

fileprivate var collectionEpisodes: Observable<[Id<Collection>:[Episode]]> =
    collections.flatMap { colls in
        theEpisodes.map { eps in
            return Dictionary(colls.map { c in
                return (c.id, c.expensive_allEpisodes)
            }, uniquingKeysWith: { x, _ in x })
        }
}

extension Collection {
    fileprivate var expensive_allEpisodes: [Episode] {
        return (episodesSource.observable.value ?? []).filter { $0.collections.contains(id) }
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
    episodesSource.flush()
    collectionsSource.flush()
    plans.flush()
    collaborators.flush()
    transcripts.flush()
    verifyStaticData()
}

func verifyStaticData() {
    myAssert(Plan.all.count >= 2)
    let episodes = Episode.all
    let colls = Collection.all
    for e in episodes {
        for c in e.collections {
            assert(colls.contains(where: { $0.id == c }), "\(c) \(e)")
        }
        for c in e.collaborators {
//            assert(Collaborator.all.contains(where: { $0.id == c}), "\(c) \(e.collaborators) \(Collaborator.all)")
        }
    }
    myAssert(transcripts.observable.value != nil)
}

extension Plan {
    static var all: [Plan] { return plans.observable.value ?? [] }
}
extension Episode {
    static var all: [Episode] { return theEpisodes.value ?? [] }
}

extension Collection {
    static var all: [Collection] { return collections.value }
    static var allDict: [Id<Collection>:Collection] { return collectionsDict.value }
    var allEpisodes: [Episode] { return collectionEpisodes.value[id] ?? [] }
}

extension Collaborator {
    static var all: [Collaborator] { return collaborators.observable.value ?? [] }
}

extension Transcript {
    static func forEpisode(number: Int) -> Transcript? {
        return (transcripts.observable.value ?? []).first { $0.number == number }
    }
}
