//
//  Routing+Helpers.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation

extension Array where Element == URL {
    func resolve(_ path: String) -> URL? {
        return lazy.map { $0.appendingPathComponent(path) }.filter { FileManager.default.fileExists(atPath: $0.path) }.first
    }
}

func absoluteURL(_ route: Route) -> URL? {
    return URL(string: "https://www.objc.io" + route.path)
}

