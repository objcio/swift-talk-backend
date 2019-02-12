//
//  Assets.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 27-11-2018.
//

import Foundation


let assets = Assets()


struct Assets {
    private var hashToFile: [String: String]
    private var fileToHash: [String: String]
    
    init() {
        let fm = FileManager.default
        var hashToFile: [String:String] = [:]
        let baseURL = URL(fileURLWithPath: fm.currentDirectoryPath).appendingPathComponent(assetsPath)
        for name in (try? fm.subpathsOfDirectory(atPath: assetsPath)) ?? [] {
            let url = baseURL.appendingPathComponent(name)
            if let d = try? Data(contentsOf: url) {
                let hashed = d.md5 + "-" + url.lastPathComponent
                hashToFile[hashed] = name
            }
        }
        self.hashToFile = hashToFile
        fileToHash = Dictionary(hashToFile.map { ($0.1, $0.0) }, uniquingKeysWith: { _, x in x })
    }

    func hashedName(file: String) -> String {
        guard let remainder = file.drop(prefix: "/\(assetsPath)/") else { return file }
        let rep = fileToHash[remainder]
        return rep.map { "/\(assetsPath)/" + $0 } ?? file
    }
    
    func fileName(hash: String) -> String? {
        return hashToFile[hash]
    }
}
