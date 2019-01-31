//
//  Helpers.swift
//  Bits
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation


var standardError = FileHandle.standardError

infix operator ?!: NilCoalescingPrecedence
func ?!<A>(lhs: A?, rhs: Error) throws -> A {
    guard let value = lhs else {
        throw rhs
    }
    return value
}

func flatten<A>(_ value: A??) -> A? {
    guard let x = value else { return nil }
    return x
}

final class Lazy<A> {
    private let compute: () throws -> A
    private var cache: A?
    private var cleanup: (A) -> ()
    func get() throws -> A {
        if cache == nil {
            cache = try compute()
        }
        return cache!
    }
    init(_ compute: @escaping () throws -> A, cleanup: @escaping (A) -> ()) {
        self.compute = compute
        self.cleanup = cleanup
    }
    
    deinit {
        guard let c = cache else { return }
        cleanup(c)
    }
}

final class Atomic<A> {
    private let queue = DispatchQueue(label: "Atomic serial queue")
    private var _value: A
    private let _didSet: ((A) -> ())?
    init(_ value: A, didSet: ((A) -> ())? = nil) {
        self._value = value
        self._didSet = didSet
    }
    
    var value: A {
        return queue.sync { self._value }
    }
    
    func mutate(_ transform: (inout A) -> ()) {
        queue.sync {
            transform(&self._value)
            _didSet?(self._value)
        }
    }
}

extension Foundation.FileHandle : TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

extension Scanner {
    var remainder: String {
        return NSString(string: string).substring(from: scanLocation)
    }
}

extension String {
    var nonEmpty: String? {
        return isEmpty ? nil : self
    }
}

func zip<A,B,R>(_ a: Either<A, [R]>, _ b: Either<B, [R]>) -> Either<(A,B), [R]> {
    guard case let .left(x) = a, case let .left(y) = b else {
        return .right((a.err ?? []) + (b.err ?? []))
    }
    return .left((x,y))
}


func zip<A,B,C,R>(_ a: Either<A, [R]>, _ b: Either<B, [R]>, _ c: Either<C, [R]>) -> Either<(A,B,C), [R]> {
    guard case let .left(x) = a, case let .left(y) = b, case let .left(z) = c else {
        return .right((a.err ?? []) + (b.err ?? []) + (c.err ?? []))
    }
    return .left((x,y,z))
}


func zip<A,B>(_ a: A?, b: B?) -> (A,B)? {
    guard let x = a, let y = b else { return nil }
    return (x,y)
}

func zip<A,B,C>(_ a: A?, b: B?, c: C?) -> (A,B, C)? {
    guard let x = a, let y = b, let z = c else { return nil }
    return (x,y,z)
}

func zip<A,B,C,D>(_ a: A?, b: B?, _ c: C?, _ d: D?) -> (A,B,C,D)? {
    guard let x = a, let y = b, let z = c, let q = d else { return nil }
    return (x,y,z,q)
}

func zip<A,B,C,D,E>(_ a: A?, b: B?, _ c: C?, _ d: D?, e: E?) -> (A,B,C,D,E)? {
    guard let x = a, let y = b, let z = c, let q = d, let r = e else { return nil }
    return (x,y,z,q,r)
}

extension String {
    // This code is copied from the Swift Standard Library
    // https://github.com/apple/swift/blob/bd109bec92f52003edff30d458ea5b2a424c9aa0/stdlib/public/SDK/Foundation/JSONEncoder.swift#L148
    // Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
    // Licensed under Apache License v2.0 with Runtime Library Exception
    var snakeCased: String {
        guard !self.isEmpty else { return self }
        let stringKey = self
        
        var words : [Range<String.Index>] = []
        // The general idea of this algorithm is to split words on transition from lower to upper case, then on transition of >1 upper case characters to lowercase
        //
        // myProperty -> my_property
        // myURLProperty -> my_url_property
        //
        // We assume, per Swift naming conventions, that the first character of the key is lowercase.
        var wordStart = stringKey.startIndex
        var searchRange = stringKey.index(after: wordStart)..<stringKey.endIndex
        
        // Find next uppercase character
        while let upperCaseRange = stringKey.rangeOfCharacter(from: CharacterSet.uppercaseLetters, options: [], range: searchRange) {
            let untilUpperCase = wordStart..<upperCaseRange.lowerBound
            words.append(untilUpperCase)
            
            // Find next lowercase character
            searchRange = upperCaseRange.lowerBound..<searchRange.upperBound
            guard let lowerCaseRange = stringKey.rangeOfCharacter(from: CharacterSet.lowercaseLetters, options: [], range: searchRange) else {
                // There are no more lower case letters. Just end here.
                wordStart = searchRange.lowerBound
                break
            }
            
            // Is the next lowercase letter more than 1 after the uppercase? If so, we encountered a group of uppercase letters that we should treat as its own word
            let nextCharacterAfterCapital = stringKey.index(after: upperCaseRange.lowerBound)
            if lowerCaseRange.lowerBound == nextCharacterAfterCapital {
                // The next character after capital is a lower case character and therefore not a word boundary.
                // Continue searching for the next upper case for the boundary.
                wordStart = upperCaseRange.lowerBound
            } else {
                // There was a range of >1 capital letters. Turn those into a word, stopping at the capital before the lower case character.
                let beforeLowerIndex = stringKey.index(before: lowerCaseRange.lowerBound)
                words.append(upperCaseRange.lowerBound..<beforeLowerIndex)
                
                // Next word starts at the capital before the lowercase we just found
                wordStart = beforeLowerIndex
            }
            searchRange = lowerCaseRange.upperBound..<searchRange.upperBound
        }
        words.append(wordStart..<searchRange.upperBound)
        let result = words.map({ (range) in
            return stringKey[range].lowercased()
        }).joined(separator: "_")
        return result
    }
    
    var base64Encoded: String {
        return data(using: .utf8)!.base64EncodedString()
    }

    func drop(prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        let remainderStart = self.index(startIndex, offsetBy: prefix.count)
        return String(self[remainderStart...])
    }
}

import Cryptor

extension Data {
    var md5: String {
        let data = Data(Digest(using: .md5).update(data: self)?.final() ?? [])
        return data.map { String(format: "%02hhx", $0) }.joined()
    }
}

func measure<A>(message: String, file: StaticString = #file, line: UInt = #line, treshold: TimeInterval = 0.01, _ code: () throws -> A) rethrows -> A {
    let start = Date()
    let result = try code()
    let time = Date().timeIntervalSince(start)
    if time > treshold {
        log(file: file, line: line, info: "measure: \(time*1000)ms \(message)")
    }
    return result
}

enum Either<A, B> {
    case left(A)
    case right(B)
}

extension Either {
    init(_ value: A?, or: @autoclosure () -> B) {
        if let x = value {
            self = .left(x)
        } else {
            self = .right(or())
        }
    }
    
    var err: B? {
        guard case let .right(e) = self else { return nil }
        return e
    }
}

extension Date {
    var isToday: Bool {
        let components = Calendar.current.dateComponents([.month,.year,.day], from: self)
        let components2 = Calendar.current.dateComponents([.month,.year,.day], from: Date())
        return components.year == components2.year && components.month == components2.month && components.day == components2.day
    }
}

extension Process {
    static func pipe(launchPath: String, _ string: String) -> String {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = []

        let out = Pipe()
        task.standardOutput = out

        let `in` = Pipe()
        task.standardInput = `in`

        task.launch()
        `in`.fileHandleForWriting.write(string)
        `in`.fileHandleForWriting.closeFile()

        let data = out.fileHandleForReading.readDataToEndOfFile()
        out.fileHandleForWriting.closeFile()

        let output = String(data: data, encoding: .utf8)
//        task.terminate() // crashes on linux
        return output ?? ""
    }
}
