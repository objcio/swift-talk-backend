//
//  Github.swift
//  Bits
//
//  Created by Chris Eidhof on 13.08.18.
//

import Foundation


let github = Github(accessToken: env.githubAccessToken)

struct Github {
    let clientId = env.githubClientId
    let clientSecret = env.githubClientSecret
    let accessToken: String
    let transcriptsRepo = "episode-transcripts"
    let staticDataRepo = "swift-talk-static-data"
    
    struct File: Codable {
        var url: URL
    }

    struct Profile: Codable {
        let login: String
        let id: Int
        let avatar_url: String
        let email: String?
        let name: String?
    }
    
    struct AccessTokenResponse: Codable, Equatable {
        var access_token: String
        var token_type: String
        var scope: String
    }
    
    init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    func getAccessToken(_ code: String) -> RemoteEndpoint<AccessTokenResponse> {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        let query = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "accept": "json"
        ]
        return RemoteEndpoint(json: .post, url: url, query: query)
    }
    
    var profile: RemoteEndpoint<Profile> {
        let url = URL(string: "https://api.github.com/user")!
        let query = ["access_token": accessToken]
        return RemoteEndpoint<Profile>(json: .get, url: url, query: query)
    }
    
    func profile(username: String) -> RemoteEndpoint<Profile> {
        let url = URL(string: "https://api.github.com/users/\(username)")!
        let query = ["access_token": accessToken]
        return RemoteEndpoint(json: .get, url: url, query: query)
    }
    
    func changeVisibility(`private`: Bool, of repository: String) -> RemoteEndpoint<Bool> {
        struct Repository: Codable {
            var name: String
            var `private`: Bool
        }
        
        let url = URL(string: "https://api.github.com/repos/objcio/\(repository)")!
        let headers = ["Authorization": "token \(accessToken)"]
        let data = Repository(name: repository, private: `private`)
        return RemoteEndpoint<Repository>(json: .patch, url: url, body: data, headers: headers).map { $0.`private` == `private` }
    }
    
    var transcripts: RemoteEndpoint<[Github.File]> {
        let url = URL(string: "https://api.github.com/repos/objcio/\(transcriptsRepo)/contents/")!
        let query = ["access_token": accessToken, "ref": "master"]
        return RemoteEndpoint<[Github.File]>(json: .get, url: url, query: query).map { files in
            return files.filter { $0.name.hasPrefix("episode") }
        }
    }
    
    func staticData<A: StaticLoadable>() -> RemoteEndpoint<[A]> {
        let url = URL(string: "https://api.github.com/repos/objcio/\(staticDataRepo)/contents/\(A.jsonName)")!
        let headers = ["Authorization": "token \(accessToken)", "Accept": "application/vnd.github.v3.raw"]
        return RemoteEndpoint(json: .get, url: url, headers: headers, decoder: Github.staticDataDecoder)
    }
    
    func contents(_ url: URL) -> RemoteEndpoint<String> {
        let headers = ["Authorization": "token \(accessToken)", "Accept": "application/vnd.github.v3.raw"]
        return RemoteEndpoint(.get, url: url, headers: headers, expectedStatusCode: expected200to300) { $0.flatMap { String(data: $0, encoding: .utf8) } }
    }
    
    static let staticDataDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .formatted(DateFormatter.iso8601)
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    static let staticDataEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .formatted(DateFormatter.iso8601)
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
}


extension Github.File {
    var repository: String {
        return url.pathComponents[3]
    }
    
    var path: String {
        return url.pathComponents[5...].joined(separator: "/")
    }
    
    var name: String {
        return url.lastPathComponent
    }
}
