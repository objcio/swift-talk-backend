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

fileprivate let episodeData = StaticJSON<[Episode]>(fileName: "data/episodes.json", process: { $0.sorted { $0.number > $1.number }})
fileprivate let episodes: Static<[Episode]> = Static(sync: episodeData.read)

let collectionData = StaticJSON<[Collection]>(fileName: "data/collections.json")
fileprivate let collections: Static<[Collection]> = Static(sync: collectionData.read)

fileprivate let collaboratorsData = StaticJSON<[Collaborator]>(fileName: "data/collaborators.json")
fileprivate let collaborators: Static<[Collaborator]> = Static(sync: collaboratorsData.read)

func refreshTranscripts() {
    Github.loadTranscripts.run { results in
        withConnection { connection in
            guard let c = connection else { return }
            for f in results {
                guard let contents = f.contents else { continue }
                let fd = FileData(repository: f.file.repository, path: f.file.path, value: contents)
                tryOrLog("Error caching \(f.file.url)") { try c.execute(fd.insertOrUpdate(uniqueKey: "key")) }
            }
        }
    }
}

func flushStaticData() {
    episodes.flush()
    collections.flush()
    plans.flush()
    collaborators.flush()
    verifyStaticData()
}

fileprivate let cachedPlanData = StaticJSON<[Plan]>(fileName: "data/plans.json")
fileprivate let plans: Static<[Plan]> = Static(async: { cb in
    cb(cachedPlanData.read())
    URLSession.shared.load(recurly.plans, callback: { value in
        cb(value)
        guard let v = value else {
            print("Could not load plans", to: &standardError)
            cb(nil)
            return
        }
        try? cachedPlanData.write(v)
    })
})

func myAssert(_ cond: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "Assertion failure \(#file):\(#line) \(#function)", file: StaticString = #file, line: UInt = #line, method: StaticString = #function) {
    // todo if production/debug
    if true {
        guard !cond() else { return }
        print(message(), to: &standardError)
    } else {
        assert(cond(), message, file: file, line: line)
    }
    
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
    static var all: [Episode] { return episodes.cached ?? [] }
}

extension Collection {
    static var all: [Collection] { return collections.cached?.filter { !$0.episodes(for: nil).isEmpty && $0.public }.sorted(by:  { $0.new && !$1.new || $0.position > $1.position }) ?? [] }
}

extension Collaborator {
    static var all: [Collaborator] { return collaborators.cached ?? [] }
}

