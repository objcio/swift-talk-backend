//
//  Endpoint.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation

enum Accept: String {
    case json = "application/json"
    case xml = "application/xml"
    case githubRaw = "application/vnd.github.v3.raw"
}

struct RemoteEndpoint<A> {
    enum Method {
        case get, post, put, patch
    }
    
    var request: URLRequest
    var parse: (Data) -> A?
    
    func map<B>(_ f: @escaping (A) -> B) -> RemoteEndpoint<B> {
        return RemoteEndpoint<B>(request: request, parse: { value in
            self.parse(value).map(f)
        })
    }

    init(_ method: Method, url: URL, accept: Accept? = nil, body: Data? = nil, headers: [String:String] = [:], query: [String:String] = [:], parse: @escaping (Data) -> A?) {
        var comps = URLComponents(string: url.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        request.httpMethod = method.string
        request.httpBody = body
        
        if let a = accept {
            request.setValue(a.rawValue, forHTTPHeaderField: "Accept")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        self.parse = parse
    }
    
    private init(request: URLRequest, parse: @escaping (Data) -> A?) {
        self.request = request
        self.parse = parse
    }
}

extension RemoteEndpoint.Method {
    var string: String {
        switch self {
        case .get: return "GET"
        case .post: return "POST"
        case .put: return "PUT"
        case .patch: return "PATCH"
        }
    }
}

extension RemoteEndpoint where A == () {
    init(_ method: Method, url: URL, accept: Accept? = nil, headers: [String:String] = [:], query: [String:String] = [:]) {
        self.init(method, url: url, accept: accept, headers: headers, query: query, parse: { _ in () })
    }

    init<B: Codable>(json method: Method, url: URL, accept: Accept? = .json, body: B, headers: [String:String] = [:], query: [String:String] = [:]) {
        let b = try! JSONEncoder().encode(body)
        self.init(method, url: url, accept: accept, body: b, headers: headers, query: query, parse: { _ in () })
    }
}

extension RemoteEndpoint where A: Decodable {
    init(json method: Method, url: URL, accept: Accept = .json, headers: [String: String] = [:], query: [String: String] = [:]) {
        self.init(method, url: url, accept: accept, body: nil, headers: headers, query: query) { data in
            return try? JSONDecoder().decode(A.self, from: data)
        }
    }

    init<B: Codable>(json method: Method, url: URL, accept: Accept = .json, body: B? = nil, headers: [String: String] = [:], query: [String: String] = [:]) {
        let b = body.map { try! JSONEncoder().encode($0) }
        self.init(method, url: url, accept: accept, body: b, headers: headers, query: query) { data in
            return try? JSONDecoder().decode(A.self, from: data)
        }
    }
}


extension URLSession {
    func load<A>(_ e: RemoteEndpoint<A>, callback: @escaping (A?) -> ()) {
        var r = e.request
        r.timeoutInterval = 10
        dataTask(with: r, completionHandler: { data, resp, err in
            guard let d = data else { callback(nil); return }
            return callback(e.parse(d))
        }).resume()
    }
    
    func load<A>(_ e: RemoteEndpoint<A>) -> Promise<A?> {
        return Promise { [unowned self] cb in
            self.load(e, callback: cb)
        }
    }
}

extension RemoteEndpoint {
    var promise: Promise<A?> {
        return URLSession.shared.load(self)
    }
}

