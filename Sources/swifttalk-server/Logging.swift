//
//  File.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 26-11-2018.
//

import Foundation


func log(file: StaticString = #file, line: UInt = #line, _ e: Error) {
    print("ERROR \(file):\(line) " + e.localizedDescription, to: &standardError)
}

func log(file: StaticString = #file, line: UInt = #line, error: String) {
    print("ERROR \(file):\(line): \(error)", to: &standardError)
}

func log(file: StaticString = #file, line: UInt = #line, info: String) {
    print("INFO \(file):\(line): \(info)")
}

@discardableResult
func tryOrLog<A>(file: StaticString = #file, line: UInt = #line, _ message: String = "", _ f: () throws -> A) -> A? {
    do {
        return try f()
    } catch {
        log(file:file, line: line, error: "\(error.localizedDescription) — \(message)")
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

