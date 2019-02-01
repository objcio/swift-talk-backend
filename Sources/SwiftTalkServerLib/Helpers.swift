//
//  Helpers.swift
//  Bits
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import Base


public func myAssert(_ cond: @autoclosure () -> Bool, _ message: @autoclosure () -> String = "Assertion failure \(#file):\(#line) \(#function)", file: StaticString = #file, line: UInt = #line, method: StaticString = #function) {
    if env.production {
        guard !cond() else { return }
        print(message(), to: &standardError)
    } else {
        assert(cond(), message, file: file, line: line)
    }
}

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

final class Atomic<A> {
    private let queue = DispatchQueue(label: "Atomic serial queue")
    private var _value: A
    init(_ value: A) {
        self._value = value
    }
    
    var value: A {
        return queue.sync { self._value }
    }
    
    func mutate(_ transform: (inout A) -> ()) {
        queue.sync {
            transform(&self._value)
        }
    }
}

extension Scanner {
    var remainder: String {
        return NSString(string: string).substring(from: scanLocation)
    }
}

extension Swift.Collection {
    var nonEmpty: Self? {
        return isEmpty ? nil : self
    }
}

public func zip<A,B,R>(_ a: Either<A, [R]>, _ b: Either<B, [R]>) -> Either<(A,B), [R]> {
    guard case let .left(x) = a, case let .left(y) = b else {
        return .right((a.err ?? []) + (b.err ?? []))
    }
    return .left((x,y))
}


public func zip<A,B,C,R>(_ a: Either<A, [R]>, _ b: Either<B, [R]>, _ c: Either<C, [R]>) -> Either<(A,B,C), [R]> {
    guard case let .left(x) = a, case let .left(y) = b, case let .left(z) = c else {
        return .right((a.err ?? []) + (b.err ?? []) + (c.err ?? []))
    }
    return .left((x,y,z))
}


public func zip<A,B>(_ a: A?, b: B?) -> (A,B)? {
    guard let x = a, let y = b else { return nil }
    return (x,y)
}

public func zip<A,B,C>(_ a: A?, b: B?, c: C?) -> (A,B, C)? {
    guard let x = a, let y = b, let z = c else { return nil }
    return (x,y,z)
}

public func zip<A,B,C,D>(_ a: A?, b: B?, _ c: C?, _ d: D?) -> (A,B,C,D)? {
    guard let x = a, let y = b, let z = c, let q = d else { return nil }
    return (x,y,z,q)
}

public func zip<A,B,C,D,E>(_ a: A?, b: B?, _ c: C?, _ d: D?, e: E?) -> (A,B,C,D,E)? {
    guard let x = a, let y = b, let z = c, let q = d, let r = e else { return nil }
    return (x,y,z,q,r)
}

extension String {
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

public enum Either<A, B> {
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

