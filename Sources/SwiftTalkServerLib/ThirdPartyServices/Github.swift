//
//  Github.swift
//  Bits
//
//  Created by Chris Eidhof on 13.08.18.
//

import Foundation
import Networking
import TinyNetworking

let github = Github(accessToken: env.githubAccessToken)

struct Github {
    let clientId = env.githubClientId
    let clientSecret = env.githubClientSecret
    let accessToken: String
    let transcriptsRepo = "episode-transcripts"
    let staticDataRepo = "swift-talk-static-data"
    
    struct File: Codable {
        var url: URL
        var sha: String
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
    
    func getAccessToken(_ code: String) -> Endpoint<AccessTokenResponse> {
        let url = URL(string: "https://github.com/login/oauth/access_token")!
        let query = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "accept": "json"
        ]
        return Endpoint(json: .post, url: url, query: query)
    }
    
    var profile: Endpoint<Profile> {
        let url = URL(string: "https://api.github.com/user")!
        let query = ["access_token": accessToken]
        return Endpoint<Profile>(json: .get, url: url, query: query)
    }
    
    func profile(username: String) -> Endpoint<Profile> {
        let url = URL(string: "https://api.github.com/users/\(username)")!
        let query = ["access_token": accessToken]
        return Endpoint(json: .get, url: url, query: query)
    }
    
    func changeVisibility(`private`: Bool, of repository: String) -> Endpoint<Bool> {
        struct Repository: Codable {
            var name: String
            var `private`: Bool
        }
        
        let url = URL(string: "https://api.github.com/repos/objcio/\(repository)")!
        let headers = ["Authorization": "token \(accessToken)"]
        let data = Repository(name: repository, private: `private`)
        return Endpoint<Repository>(json: .patch, url: url, body: data, headers: headers).map { $0.`private` == `private` }
    }
    
    private var transcriptFiles: Endpoint<[Github.File]> {
        let url = URL(string: "https://api.github.com/repos/objcio/\(transcriptsRepo)/contents/")!
        let query = ["access_token": accessToken, "ref": "master"]
        return Endpoint<[Github.File]>(json: .get, url: url, query: query).map { files in
            return files.filter { $0.name.hasPrefix("episode") }
        }
    }

    private func contents(_ file: File) -> Endpoint<(file: File, content: String)> {
        let headers = ["Authorization": "token \(accessToken)", "Accept": "application/vnd.github.v3.raw"]
        return Endpoint(.get, url: file.url, headers: headers) { data, _ in
            guard let d = data, let str = String(data: d, encoding: .utf8) else { return .failure(DecodingError(message: "Expected UTF8")) }
            return .success((file: file, content: str))
        }
    }

    func transcripts(knownShas: [String]) -> CombinedEndpoint<[(file: File, content: String)]> {
        return transcriptFiles.map { files in
            files.filter { !knownShas.contains($0.sha) }
        }.c.flatMap { files in
            guard !files.isEmpty else { return nil }
            let batches = files.chunked(size: 5).map { batch in
                zip(batch.map { self.contents($0).c })!
            }
            return sequentially(delay: 0.1, batches)!.map { Array($0.joined()) }
        }
    }
    
    func staticData<A: StaticLoadable>() -> Endpoint<[A]> {
        let url = URL(string: "https://api.github.com/repos/objcio/\(staticDataRepo)/contents/\(A.jsonName)")!
        let headers = ["Authorization": "token \(accessToken)", "Accept": "application/vnd.github.v3.raw"]
        return Endpoint(json: .get, url: url, headers: headers, decoder: Github.staticDataDecoder)
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
