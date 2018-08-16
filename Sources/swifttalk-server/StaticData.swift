//
//  StaticData.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation

func loadStaticData() {
    for e in Episode.all {
        for c in e.collections {
            assert(Collection.all.contains(where: { $0.title == c }))
        }
    }
}

extension Episode {
    static let all: [Episode] = {
        // for this (and the rest of the app) to work we need to launch with a correct working directory (root of the app)
        let d = try! Data(contentsOf: URL(fileURLWithPath: "data/episodes.json"))
        let e = try! JSONDecoder().decode([Episode].self, from: d)
        return e.sorted { $0.number > $1.number }
        
    }()
    
}

extension Collection {
    static let all: [Collection] = {
        // for this (and the rest of the app) to work we need to launch with a correct working directory (root of the app)
        let d = try! Data(contentsOf: URL(fileURLWithPath: "data/collections.json"))
        let e = try! JSONDecoder().decode([Collection].self, from: d)
        return e
    }()
}

