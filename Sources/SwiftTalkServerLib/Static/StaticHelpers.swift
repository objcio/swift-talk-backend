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
                onRefresh(data)
                cb(data)
            }
        })
    }
}

func queryTranscripts() -> [Transcript] {
    return tryOrLog { try withConnection { connection in
        let rows = try connection.execute(Row<FileData>.transcripts())
        return rows.compactMap { f in Transcript(fileName: f.data.key, raw: f.data.value) }
    }} ?? []
}

private func loadTranscripts() -> Promise<[(file: Github.File, contents: String?)]> {
    return URLSession.shared.load(github.transcripts).flatMap { transcripts in
        let files = transcripts ?? []
        let promises = files
            .map { (file: $0, endpoint: github.contents($0.url)) }
            .map { (file: $0.file, promise: URLSession.shared.load($0.endpoint)) }
            .map { t in t.promise.map { (file: t.file, contents: $0) } }
        return sequentially(promises)
    }
}

func refreshTranscripts(onCompletion: @escaping () -> ()) {
    loadTranscripts().run { results in
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

