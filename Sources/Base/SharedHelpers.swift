//
//  Helpers.swift
//  Bits
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation


public enum HTTPMethod: String, Codable {
    case post = "POST"
    case get = "GET"
}

public struct Request {
    public var path: [String]
    public var query: [String:String]
    public var method: HTTPMethod
    public var cookies: [(String, String)]
}

extension Request {
    public init(_ uri: String, method: HTTPMethod = .get, cookies: [(String,String)] = []) {
        let (p,q) = uri.parseQuery
        path = p.split(separator: "/").map(String.init)
        query = q
        self.method = method
        self.cookies = cookies
    }
}

public final class Lazy<A> {
    private let compute: () throws -> A
    private var cache: A?
    private var cleanup: (A) -> ()
    
    public func get() throws -> A {
        if cache == nil {
            cache = try compute()
        }
        return cache!
    }
    
    public init(_ compute: @escaping () throws -> A, cleanup: @escaping (A) -> ()) {
        self.compute = compute
        self.cleanup = cleanup
    }
    
    deinit {
        guard let c = cache else { return }
        cleanup(c)
    }
}

extension Array where Element == URL {
    public func resolve(_ path: String) -> URL? {
        return lazy.map { $0.appendingPathComponent(path) }.filter { FileManager.default.fileExists(atPath: $0.path) }.first
    }
}

extension String {
    fileprivate var decoded: String {
        return (removingPercentEncoding ?? "").replacingOccurrences(of: "+", with: " ")
    }
}

extension StringProtocol {
    public var keyAndValue: (String, String)? {
        guard let i = index(of: "=") else { return nil }
        let n = index(after: i)
        return (String(self[..<i]), String(self[n...]).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
    }
    
    public var parseAsQueryPart: [String:String] {
        let items = split(separator: "&").compactMap { $0.keyAndValue }
        return Dictionary(items.map { (k, v) in (k.decoded, v.decoded) }, uniquingKeysWith: { $1 })
    }

    fileprivate var parseQuery: (String, [String:String]) {
        guard let i = self.index(of: "?") else { return (String(self), [:]) }
        let path = self[..<i]
        let remainder = self[index(after: i)...]
        return (String(path), remainder.parseAsQueryPart)
    }
}

public func measure<A>(message: String, file: StaticString = #file, line: UInt = #line, treshold: TimeInterval = 0.01, _ code: () throws -> A) rethrows -> A {
    let start = Date()
    let result = try code()
    let time = Date().timeIntervalSince(start)
    if time > treshold {
        log(file: file, line: line, info: "measure: \(time*1000)ms \(message)")
    }
    return result
}

