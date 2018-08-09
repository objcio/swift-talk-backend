//
//  Endpoint.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation

enum Accept: String {
    case json = "application/json"
}

struct GithubProfile: Codable {
    let login: String
    let id: Int
    let avatar_url: String
    let email: String?
    let name: String?
    // todo we get more than this, but should be enough info
}

struct RemoteEndpoint<A> {
    var request: URLRequest
    var parse: (Data) -> A?
    
    init(get: URL, accept: Accept? = nil, query: [String:String], parse: @escaping (Data) -> A?) {
        var comps = URLComponents(string: get.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        if let a = accept {
            request.setValue(a.rawValue, forHTTPHeaderField: "Accept")
        }
        self.parse = parse
    }
    
    init(post: URL, accept: String? = nil, query: [String:String], parse: @escaping (Data) -> A?) {
        var comps = URLComponents(string: post.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        request.httpMethod = "POST"

        if let a = accept {
            request.setValue(a, forHTTPHeaderField: "Accept")
        }
        self.parse = parse
    }
}

extension RemoteEndpoint where A: Decodable {
    /// Parses the result as JSON
    init(post: URL, query: [String:String]) {
        var comps = URLComponents(string: post.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        request.setValue(Accept.json.rawValue, forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        self.parse = { data in
            return try? JSONDecoder().decode(A.self, from: data)
        }
    }
    
    init(get: URL, query: [String:String] = [:]) {
        self.init(get: get, accept: Accept.json, query: query, parse: { data in
            return try? JSONDecoder().decode(A.self, from: data)
        })
    }
}

extension URLSession {
    func load<A>(_ e: RemoteEndpoint<A>, callback: @escaping (A?) -> ()) {
        var r = e.request
        r.timeoutInterval = 2 // todo?
        dataTask(with: r, completionHandler: { data, resp, err in
            guard let d = data else { callback(nil); return }
            return callback(e.parse(d))
        }).resume()
    }
    
    func load<A>(_ e: RemoteEndpoint<A>) -> Promise<A?> {
        return Promise { [unowned self] cb in
            var r = e.request
            r.timeoutInterval = 2 // todo?
            self.dataTask(with: r, completionHandler: { data, resp, err in
                guard let d = data else { cb(nil); return }
                return cb(e.parse(d))
            }).resume()
        }
    }
}

struct Github {
    // todo initialize?
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
