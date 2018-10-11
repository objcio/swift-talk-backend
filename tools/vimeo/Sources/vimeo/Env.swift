//
//  Env.swift
//  vimeo
//
//  Created by Chris Eidhof on 11.10.18.
//

import Foundation

var standardError = FileHandle.standardError

extension Foundation.FileHandle : TextOutputStream {
    public func write(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        self.write(data)
    }
}

extension StringProtocol {
    var keyAndValue: (String, String)? {
        guard let i = index(of: "=") else { return nil }
        let n = index(after: i)
        return (String(self[..<i]), String(self[n...]).trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
    }
}


func readDotEnv() -> [String:String] {
    guard let c = try? String(contentsOfFile: ".env") else { return [:] }
    return Dictionary(c.split(separator: "\n").compactMap { $0.keyAndValue }, uniquingKeysWith: { $1 })
}

struct Env {
    let env: [String:String] = readDotEnv().merging(ProcessInfo.processInfo.environment, uniquingKeysWith: { $1 })
    
    subscript(optional string: String) -> String? {
        return env[string]
    }
    
    subscript(string: String) -> String {
        guard let e = env[string] else {
            print("Forgot to set env variable \(string)", to: &standardError)
            return ""
        }
        return e
    }  
}

