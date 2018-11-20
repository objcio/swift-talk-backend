//
//  Helpers.swift
//  Bits
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation


extension String {
    var base64Encoded: String {
        return data(using: .utf8)!.base64EncodedString()
    }
}

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

func log(_ e: Error) {
    print(e.localizedDescription, to: &standardError)
}

func log(error: String) {
    print(error, to: &standardError)
}

@discardableResult
func tryOrLog<A>(_ message: String = "", _ f: () throws -> A) -> A? {
    do {
        return try f()
    } catch {
        log(error: "\(error.localizedDescription) — \(message)")
        return nil
    }
}

func myAssert(_ cond: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "Assertion failure \(#file):\(#line) \(#function)", file: StaticString = #file, line: UInt = #line, method: StaticString = #function) {
    if env.production {
        guard !cond() else { return }
        print(message(), to: &standardError)
    } else {
        assert(cond(), message, file: file, line: line)
    }
    
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
}

