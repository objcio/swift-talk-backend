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

protocol StaticLoadable: Codable {
    static var jsonName: String { get }
}

extension Collaborator: StaticLoadable {
    static var jsonName: String { return "collaborators.json" }
}

extension Episode: StaticLoadable {
    static var jsonName: String { return "episodes.json" }
}

extension Collection: StaticLoadable {
    static var jsonName: String { return "collections.json" }
}



// todo we could have a struct/func that caches/reads cached JSON data

// todo: chris I think we can make the three functions below a lot simpler...

fileprivate func loadStaticData<A: Codable>(name: String) -> [A] {
    return tryOrLog { try withConnection { connection in
        guard
            let row = try connection.execute(Row<FileData>.staticData(jsonName: name)),
            let result = try? JSONDecoder().decode([A].self, from: row.data.value.data(using: .utf8)!)
            else { return [] }
        return result
    }} ?? []
}

fileprivate func cacheStaticData<A: Codable>(_ data: A, name: String) {
    tryOrLog { try withConnection { connection in
        guard
            let encoded = try? JSONEncoder().encode(data),
            let json = String(data: encoded, encoding: .utf8)
            else { log(error: "Unable to encode static data \(name)"); return }
        let fd = FileData(repository: github.staticDataRepo, path: name, value: json)
        tryOrLog("Error caching \(name) in database") { try connection.execute(fd.insertOrUpdate(uniqueKey: "key")) }
    }}
}

fileprivate func refreshStaticData<A: StaticLoadable>(_ endpoint: RemoteEndpoint<[A]>, onCompletion: @escaping () -> ()) {
    URLSession.shared.load(endpoint) { result in
        tryOrLog { try withConnection { connection in
            guard let r = result else { log(error: "Failed loading static data \(A.jsonName)"); return }
            cacheStaticData(r, name: A.jsonName)
            onCompletion()
        }}
    }
}

extension Static {
    static func fromStaticRepo<A: StaticLoadable>(onRefresh: @escaping ([A]) -> () = { _ in }) -> Static<[A]> {
        return Static<[A]>(async: { cb in
            let initial: [A] = loadStaticData(name: A.jsonName)
            cb(initial)
            let ep: RemoteEndpoint<[A]> = github.staticData()
            refreshStaticData(ep) {
                let data: [A] = loadStaticData(name: A.jsonName)
                cb(data)
                onRefresh(data)
            }
        })
    }
}

// Todo: this is a bit of a mess, we could look into this.


fileprivate let episodesSource: Static<[Episode]> = .fromStaticRepo(onRefresh: { newEpisodes in
    for ep in newEpisodes where ep.releaseAt > Date() {
        let query = Task.releaseEpisode(number: ep.number).schedule(at: ep.releaseAt)
        tryOrLog("Failed to schedule release task for episode \(ep.number)") { try lazyConnection().get().execute(query) }
    }
})

fileprivate let collectionsSource: Static<[Collection]> = .fromStaticRepo()



fileprivate let episodes: Observable<[Episode]> = episodesSource.observable.map { eps in
    guard let e = eps else { return [] }
    return e.sorted { $0.number > $1.number }
}

fileprivate let collections: Observable<[Collection]> = collectionsSource.observable.map { (colls: [Collection]?) in
    guard let c = colls else { return [] }
    return c.filter { !$0.expensive_allEpisodes.isEmpty && $0.public }.sorted(by:  { $0.new && !$1.new || $0.position > $1.position })
}

fileprivate let collectionsDict: Observable<[Id<Collection>:Collection]> = collections.map { (colls: [Collection]?) in
    guard let c = colls else { return [:] }
    return Dictionary.init(c.map { ($0.id, $0) }, uniquingKeysWith: { a, b in a })
}

let hashedAssets: Static<(hashToFile: [String:String], fileToHash: [String:String])> = Static(sync: {
    // todo should be async...
    let fm = FileManager.default
    var hashToFile: [String:String] = [:]
    let baseURL = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent("assets")
    for name in (try? fm.subpathsOfDirectory(atPath: "assets")) ?? [] {
        let url = baseURL.appendingPathComponent(name)
        if let d = try? Data(contentsOf: url) {
            let hashed = d.md5 + "-" + url.lastPathComponent
        	hashToFile[hashed] = name
        }
    }
    let fileToHash = Dictionary(hashToFile.map { ($0.1, $0.0) }, uniquingKeysWith: { _, x in x })
    return (hashToFile: hashToFile, fileToHash: fileToHash)
})

fileprivate var collectionEpisodes: Observable<[Id<Collection>:[Episode]]> = collections.flatMap { colls in
    episodes.map { eps in
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


fileprivate let collaborators: Static<[Collaborator]> = Static<[Collaborator]>.fromStaticRepo()

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

fileprivate let plans: Static<[Plan]> = Static(async: { cb in
    let jsonName = "plans.json"
    let initial: [Plan] = loadStaticData(name: jsonName)
    cb(initial)
    URLSession.shared.load(recurly.plans) { value in
        cb(value)
        guard let v = value else { log(error: "Could not load plans from Recurly"); return }
        cacheStaticData(v, name: jsonName)
    }
})


func flushStaticData() {
    hashedAssets.flush()
    episodesSource.flush()
    collectionsSource.flush()
    plans.flush()
    collaborators.flush()
    transcripts.flush()
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
    myAssert(transcripts.observable.value != nil)
}

extension Plan {
    static var all: [Plan] { return plans.observable.value ?? [] }
}

extension Episode {
    static var all: [Episode] { return episodes.value }
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
