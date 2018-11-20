//
//  Environment.swift
//  Bits
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation


let env = Env()

func readDotEnv() -> [String:String] {
    guard let c = try? String(contentsOfFile: ".env") else { return [:] }
    return Dictionary(c.split(separator: "\n").compactMap { $0.keyAndValue }, uniquingKeysWith: { $1 })
}

struct Env {
    let env: [String:String] = readDotEnv().merging(ProcessInfo.processInfo.environment, uniquingKeysWith: { $1 })
    
    init() {
        guard
            let _ = env["BASE_URL"],
            let _ = env["GITHUB_CLIENT_ID"],
            let _ = env["GITHUB_CLIENT_SECRET"],
            let _ = env["GITHUB_ACCESS_TOKEN"],
            let _ = env["RECURLY_SUBDOMAIN"],
            let _ = env["RECURLY_PUBLIC_KEY"],
            let _ = env["RECURLY_API_KEY"],
            let _ = env["CIRCLE_API_KEY"],
            let _ = env["MAILCHIMP_API_KEY"],
            let _ = env["MAILCHIMP_LIST_ID"],
            let _ = env["VIMEO_ACCESS_TOKEN"]
        else { fatalError("Missing environment variable") }
    }

    var baseURL: URL { return URL(string: env["BASE_URL"]!)! }

    var port: Int? { return env["PORT"].flatMap(Int.init) }
    
    var databaseURL: String? { return env["DATABASE_URL"] }
    var databaseHost: String { return env["RDS_HOSTNAME"] ?? "localhost" }
    var databaseName: String { return env["RDS_DB_NAME"] ?? "swifttalk_dev" }
    var databaseUser: String { return env["RDS_DB_USERNAME"] ?? "chris" }
    var databasePassword: String { return env["RDS_DB_PASSWORD"] ?? "" }
    
    var githubClientId: String { return env["GITHUB_CLIENT_ID"]! }
    var githubClientSecret: String { return env["GITHUB_CLIENT_SECRET"]! }
    var githubAccessToken: String { return env["GITHUB_ACCESS_TOKEN"]! }
    
    var recurlySubdomain: String { return env["RECURLY_SUBDOMAIN"]! }
    var recurlyPublicKey: String { return env["RECURLY_PUBLIC_KEY"]! }
    var recurlyApiKey: String { return env["RECURLY_API_KEY"]! }
    
    var circleApiKey: String { return env["CIRCLE_API_KEY"]! }
    
    var mailchimpApiKey: String { return env["MAILCHIMP_API_KEY"]! }
    var mailchimpListId: String { return env["MAILCHIMP_LIST_ID"]! }
    
    // The vimeo access token needs to have the "private" and "files" roles enabled to fetch the download urls for private videos
    var vimeoAccessToken: String { return env["VIMEO_ACCESS_TOKEN"]! }
}

