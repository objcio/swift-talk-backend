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
            print(error, to: &standardError)
            print(error.localizedDescription, to: &standardError)
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
    return withConnection { connection in
        guard
            let c = connection,
            let row = try? c.execute(Row<FileData>.staticData(jsonName: A.jsonName)),
            let r = row,
            let result = try? JSONDecoder().decode([A].self, from: r.data.value.data(using: .utf8)!)
            else { return [] }
        return result
    }
}

func refreshStaticData<A: StaticLoadable>(_ endpoint: RemoteEndpoint<[A]>, onCompletion: @escaping () -> ()) {
    URLSession.shared.load(endpoint) { result in
        withConnection { connection in
            guard
                let c = connection,
                let r = result,
                let data = try? JSONEncoder().encode(r),
                let json = String(data: data, encoding: .utf8)
                else { return }
            let fd = FileData(repository: Github.staticDataRepo, path: A.jsonName, value: json)
            tryOrLog("Error caching \(A.jsonName)") { try c.execute(fd.insertOrUpdate(uniqueKey: "key")) }
            onCompletion()
        }
    }
}

extension Static {
    static func fromStaticRepo<A: StaticLoadable>() -> Static<[A]> {
        return Static<[A]>(async: { cb in
            cb(loadStaticData())
            let ep: RemoteEndpoint<[A]> = Github.staticData()
            refreshStaticData(ep) {
                cb(loadStaticData())
            }
        })
    }
}

fileprivate let episodes: Static<[Episode]> = Static<[Episode]>.fromStaticRepo()
fileprivate let collections: Static<[Collection]> = Static<[Collection]>.fromStaticRepo()
fileprivate let collaborators: Static<[Collaborator]> = Static<[Collaborator]>.fromStaticRepo()


fileprivate func loadTranscripts() -> [Transcript] {
    return withConnection { connection in
        guard let c = connection, let rows = try? c.execute(Row<FileData>.transcripts()) else { return [] }
        return rows.compactMap { f in Transcript(fileName: f.data.key, raw: f.data.value) }
    }
}

func refreshTranscripts(onCompletion: @escaping () -> ()) {
    Github.loadTranscripts.run { results in
        withConnection { connection in
            guard let c = connection else { return }
            for f in results {
                guard let contents = f.contents else { continue }
                let fd = FileData(repository: f.file.repository, path: f.file.path, value: contents)
                tryOrLog("Error caching \(f.file.url)") { try c.execute(fd.insertOrUpdate(uniqueKey: "key")) }
            }
            onCompletion()
        }
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
    episodes.flush()
    collections.flush()
    plans.flush()
    collaborators.flush()
    transcripts.flush()
    verifyStaticData()
}

func verifyStaticData() {
    myAssert(Plan.all.count >= 2)
    for e in Episode.all {
        for c in e.collections {
            assert(Collection.all.contains(where: { $0.id == c }), "\(c) \(e)")
        }
        for c in e.collaborators {
            assert(Collaborator.all.contains(where: { $0.id == c}), "\(c) \(e)")
        }
    }
}

extension Plan {
    static var all: [Plan] { return plans.cached ?? [] }
}
extension Episode {
    static var all: [Episode] { return (episodes.cached ?? []).sorted { $0.number > $1.number } }
}

extension Collection {
    static var all: [Collection] { return collections.cached?.filter { !$0.episodes(for: nil).isEmpty && $0.public }.sorted(by:  { $0.new && !$1.new || $0.position > $1.position }) ?? [] }
}

extension Collaborator {
    static var all: [Collaborator] { return collaborators.cached ?? [] }
}

extension Transcript {
    static func forEpisode(number: Int) -> Transcript? {
        return (transcripts.cached ?? []).first { $0.number == number }
    }
}
