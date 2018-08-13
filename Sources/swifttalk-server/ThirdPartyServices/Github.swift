//
//  Github.swift
//  Bits
//
//  Created by Chris Eidhof on 13.08.18.
//

import Foundation

struct GithubProfile: Codable {
    let login: String
    let id: Int
    let avatar_url: String
    let email: String?
    let name: String?
    // todo we get more than this, but should be enough info
}


struct Github {
    // todo initialize? We could also have an "AuthenticatedGithub" struct which requires the access token.
    static var clientId: String { return env["GITHUB_CLIENT_ID"] }
    static var clientSecret: String { return env["GITHUB_CLIENT_SECRET"] }
    
    static let contentType = "application/json"
    
    struct AccessTokenResponse: Codable, Equatable {
        var access_token: String
        var token_type: String
        var scope: String
    }
    
    let accessToken: String
    init(_ accessToken: String) {
        self.accessToken = accessToken
    }
    
    static func getAccessToken(_ code: String) -> RemoteEndpoint<AccessTokenResponse> {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        let query = [
            "client_id": Github.clientId,
            "client_secret": Github.clientSecret,
            "code": code,
            "accept": "json"
        ]
        return RemoteEndpoint(post: url, query: query)
    }
    
    var profile: RemoteEndpoint<GithubProfile> {
        let url = URL(string: "https://api.github.com/user")!
        let query = ["access_token": accessToken]
        return RemoteEndpoint(get: url, query: query)
    }
}
