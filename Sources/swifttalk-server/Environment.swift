//
//  Environment.swift
//  Bits
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation

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
    
    init() {
        guard
            let _ = env["BASE_URL"],
            let _ = env["GITHUB_CLIENT_ID"],
            let _ = env["GITHUB_CLIENT_SECRET"],
            let _ = env["GITHUB_ACCESS_TOKEN"],
            let _ = env["RECURLY_SUBDOMAIN"],
            let _ = env["RECURLY_PUBLIC_KEY"],
            let _ = env["CIRCLE_API_KEY"],
            let _ = env["MAILCHIMP_API_KEY"],
            let _ = env["MAILCHIMP_LIST_ID"],
            let _ = env["VIMEO_ACCESS_TOKEN"]
        else { fatalError("Missing environment variable") }
    }
    
    var recurlyPublicKey: String {
        return self["RECURLY_PUBLIC_KEY"]
    }
    
    var port: Int? {
        return env["PORT"].flatMap(Int.init)
    }
}

