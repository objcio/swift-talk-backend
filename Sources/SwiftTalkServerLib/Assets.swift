//
//  Assets.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 27-11-2018.
//

import Foundation


let assets = Assets()


struct Assets {
    private var hashToFile: [String: (original: String, gzipped: String?)]
    private var fileToHash: [String: (hash: String, gzipped: String?)]
    
    init() {
        let fm = FileManager.default
        var hashToFile: [String:(original: String, gzipped: String?)] = [:]
        let baseURL = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(assetsPath)
        let names = (try? fm.subpathsOfDirectory(atPath: assetsPath)) ?? []
        let zipped = names.filter { $0.hasSuffix(".gz" )}
        for name in names.filter({ !$0.hasSuffix("gz") }) {
            let url = baseURL.appendingPathComponent(name)
            if let d = try? Data(contentsOf: url) {
                let hashed = d.md5 + "-" + url.lastPathComponent
                let gzip = name + ".gz"
                hashToFile[hashed] = (name, zipped.contains(gzip) ? gzip : nil)
            }
        }
        self.hashToFile = hashToFile
        fileToHash = Dictionary(hashToFile.map { ($0.1.original, (hash: $0.0, gzipped: $0.1.gzipped)) }, uniquingKeysWith: { _, x in x })
    }

    func hashedName(file: String) -> String {
        guard let remainder = file.drop(prefix: "/\(assetsPath)/") else { return file }
        let rep = fileToHash[remainder]?.hash
        return rep.map { "/\(assetsPath)/" + $0 } ?? file
    }
    
    func fileName(hash: String) -> (original: String, gzipped: String?)? {
        return hashToFile[hash]
    }
}
