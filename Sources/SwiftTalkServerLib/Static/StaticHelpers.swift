//
//  StaticHelpers.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 27-11-2018.
//

import Foundation


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

func loadStaticData<A: Codable>(name: String) -> [A] {
    return tryOrLog { try withConnection { connection in
        guard
            let row = try connection.execute(Row<FileData>.staticData(jsonName: name)),
            let result = try? Github.staticDataDecoder.decode([A].self, from: row.data.value.data(using: .utf8)!)
            else { return [] }
        return result
    }} ?? []
}

func cacheStaticData<A: Codable>(_ data: A, name: String) {
    tryOrLog { try withConnection { connection in
        guard
            let encoded = try? Github.staticDataEncoder.encode(data),
            let json = String(data: encoded, encoding: .utf8)
            else { log(error: "Unable to encode static data \(name)"); return }
        let fd = FileData(repository: github.staticDataRepo, path: name, value: json)
        tryOrLog("Error caching \(name) in database") { try connection.execute(fd.insertOrUpdate(uniqueKey: "key")) }
    }}
}

fileprivate func refreshStaticData<A: StaticLoadable>(_ endpoint: RemoteEndpoint<[A]>, onCompletion: @escaping () -> ()) {
    globals.urlSession.load(endpoint) { result in
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
                onRefresh(data)
                cb(data)
            }
        })
    }
}

func queryTranscripts(fast: Bool = false, _ cb: @escaping ([Transcript]) -> ()) {
    if fast {
        cb(queryTranscriptsHelper(fast: true))
    } else {
        DispatchQueue.global(qos: .userInitiated).async {
            print("Starting highlighting")
            let res = queryTranscriptsHelper(fast: false)
            print("Done highlighting")
            cb(res)
        }
    }
}

func queryTranscriptsHelper(fast: Bool = false) -> [Transcript] {
    return tryOrLog { try withConnection { connection in
        let rows = try connection.execute(Row<FileData>.transcripts())
        return rows.compactMap { f in Transcript(fileName: f.data.key, raw: f.data.value, highlight: !fast) }
    }} ?? []
}

func refreshTranscripts(onCompletion: @escaping () -> ()) {
    globals.urlSession.load(github.transcripts) { results in
        guard let transcripts = results else { log(error: "Failed to load transcripts"); return }
        tryOrLog { try withConnection { connection in
            for t in transcripts {
                let fd = FileData(repository: t.file.repository, path: t.file.path, value: t.content)
                tryOrLog("Error caching \(t.file.url)") { try connection.execute(fd.insertOrUpdate(uniqueKey: "key")) }
            }
            onCompletion()
        }}
    }
}

