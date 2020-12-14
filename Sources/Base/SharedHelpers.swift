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
    case head = "HEAD"
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
    fileprivate var decoded: String? {
        return replacingOccurrences(of: "+", with: " ").removingPercentEncoding
    }
}

extension StringProtocol {
    public var keyAndValue: (String, String)? {
        guard let i = firstIndex(of: "=") else { return nil }
        let n = index(after: i)
        return (String(self[..<i]), String(self[n...]).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
    }
    
    public var parseAsQueryPart: [String:String] {
        let items = split(separator: "&").compactMap { $0.keyAndValue }
        return Dictionary(items.map { (k, v) in (k.decoded ?? "", v.decoded ?? "") }, uniquingKeysWith: { $1 })
    }

    fileprivate var parseQuery: (String, [String:String]) {
        guard let i = self.firstIndex(of: "?") else { return (String(self), [:]) }
        let path = self[..<i]
        let remainder = self[index(after: i)...]
        return (String(path), remainder.parseAsQueryPart)
    }
}

extension DateFormatter {
    static public let iso8601WithTrailingZ: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }()
}

public func measure<A>(message: String, file: StaticString = #file, line: UInt = #line, threshold: TimeInterval = 0.01, _ code: () throws -> A) rethrows -> A {
    let start = Date()
    let result = try code()
    let time = Date().timeIntervalSince(start)
    if time > threshold {
        log(file: file, line: line, info: "measure: \(time*1000)ms \(message)")
    }
    return result
}

public func flatten<A>(_ value: A??) -> A? {
    guard let x = value else { return nil }
    return x
}

public enum Either<A, B> {
    case left(A)
    case right(B)
}

extension Either {
    public init(_ value: A?, or: @autoclosure () -> B) {
        if let x = value {
            self = .left(x)
        } else {
            self = .right(or())
        }
    }
    
    public var err: B? {
        guard case let .right(e) = self else { return nil }
        return e
    }
}


infix operator ?!: NilCoalescingPrecedence
public func ?!<A>(lhs: A?, rhs: Error) throws -> A {
    guard let value = lhs else {
        throw rhs
    }
    return value
}

extension Collection {
    public func intersperse(_ sep: Element) -> [Element] {
        guard let f = self.first else { return [] }
        return dropFirst().reduce(into: [f], { x, el in
            x.append(sep)
            x.append(el)
        })
        
    }
}

extension Collection where Index: Strideable {
    public func chunked(size: Index.Stride) -> [[Element]] {
        return stride(from: startIndex, to: endIndex, by: size).map { startIndex in
            let next = startIndex.advanced(by: size)
            let end = next <= endIndex ? next : endIndex
            return Array(self[startIndex ..< end])
        }
    }
}

final public class Atomic<A> {
    private let queue = DispatchQueue(label: "Atomic serial queue")
    private var _value: A
    public init(_ value: A) {
        self._value = value
    }
    
    public var value: A {
        return queue.sync { self._value }
    }
    
    public func mutate(_ transform: (inout A) -> ()) {
        queue.sync {
            transform(&self._value)
        }
    }
}

extension RandomAccessCollection where Index == Int {
    public func concurrentCompactMap<B>(_ transform: @escaping (Element) -> B?) -> [B] {
        return concurrentMap(transform).filter { $0 != nil }.map { $0! }
    }
    
    public func concurrentMap<B>(_ transform: @escaping (Element) -> B) -> [B] {
        let result = Atomic([B?](repeating: nil, count: count))
        DispatchQueue.concurrentPerform(iterations: count) { idx in
            let element = self[idx]
            let transformed = transform(element)
            result.mutate {
                $0[idx] = transformed
            }
        }
        return result.value.map { $0! }
        
    }
}
