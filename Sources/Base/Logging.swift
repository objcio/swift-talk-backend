//
//  Logging.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 26-11-2018.
//

import Foundation

public var standardError = FileHandle.standardError

extension Foundation.FileHandle : TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

public func log(file: StaticString = #file, line: UInt = #line, _ e: Error) {
    print("ERROR \(file):\(line) ", to: &standardError)
    dump(e, to: &standardError)
    standardError.synchronizeFile()
}

public func log(file: StaticString = #file, line: UInt = #line, error: String) {
    print("ERROR \(file):\(line): \(error)", to: &standardError)
    standardError.synchronizeFile()
}

public func log(file: StaticString = #file, line: UInt = #line, info: String) {
    print("INFO \(file):\(line): \(info)")
    FileHandle.standardOutput.synchronizeFile()
}

@discardableResult
public func tryOrLog<A>(file: StaticString = #file, line: UInt = #line, _ message: String = "", _ f: () throws -> A) -> A? {
    do {
        return try f()
    } catch {
        log(file:file, line: line, error: "\(error.localizedDescription) — \(message)")
        return nil
    }
}


