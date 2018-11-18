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
}

struct RemoteEndpoint<A> {
    var request: URLRequest
    var parse: (Data) -> A?
    
    init(request: URLRequest, parse: @escaping (Data) -> A?) {
        self.request = request
        self.parse = parse
    }
    
    init(get url: URL, accept: Accept? = nil, headers: [String:String] = [:], query: [String:String], parse: @escaping (Data) -> A?) {
        self.init(method: "GET", url: url, accept: accept, body: nil, headers: headers, query: query, parse: parse)
    }
    
    init(post url: URL, accept: Accept? = nil, body: Data? = nil, headers: [String:String] = [:], query: [String:String], parse: @escaping (Data) -> A?) {
        self.init(method: "POST", url: url, accept: accept, body: body, headers: headers, query: query, parse: parse)
    }

    init(put url: URL, accept: Accept? = nil, body: Data? = nil, headers: [String:String] = [:], query: [String:String], parse: @escaping (Data) -> A?) {
        self.init(method: "PUT", url: url, accept: accept, body: body, headers: headers, query: query, parse: parse)
    }

    init(patch url: URL, accept: Accept? = nil, body: Data? = nil, headers: [String:String] = [:], query: [String:String], parse: @escaping (Data) -> A?) {
        self.init(method: "PATCH", url: url, accept: accept, body: body, headers: headers, query: query, parse: parse)
    }

    private init(method: String, url: URL, accept: Accept? = nil, body: Data? = nil, headers: [String:String] = [:], query: [String:String], parse: @escaping (Data) -> A?) {
        var comps = URLComponents(string: url.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        request.httpMethod = method
        request.httpBody = body
        
        if let a = accept {
            request.setValue(a.rawValue, forHTTPHeaderField: "Accept")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        self.parse = parse
    }
    
    func map<B>(_ f: @escaping (A) -> B) -> RemoteEndpoint<B> {
        return RemoteEndpoint<B>(request: request, parse: { value in
            self.parse(value).map(f)
        })
    }
}

extension RemoteEndpoint where A: Decodable {
    /// Parses the result as JSON
    init(postJSON url: URL, headers: [String: String] = [:], query: [String:String]) {
        self.init(postJSON: url, body: Optional<Bool>.none, headers: headers, query: query)
    }
    
    init<B: Codable>(postJSON url: URL, body: B?, headers: [String: String] = [:], query: [String:String]) {
        self.init(method: "POST", url: url, body: body, headers: headers, query: query)
    }
    
    init<B: Codable>(patchJSON url: URL, body: B?, headers: [String: String] = [:], query: [String:String]) {
        self.init(method: "PATCH", url: url, body: body, headers: headers, query: query)
    }
    
    init(getJSON url: URL, headers: [String:String] = [:], query: [String:String] = [:]) {
        self.init(method: "GET", url: url, body: Optional<Bool>.none, headers: headers, query: query)
    }
    
    private init<B: Codable>(method: String, url: URL, body: B?, headers: [String: String] = [:], query: [String: String] = [:]) {
        let b = body.map { try! JSONEncoder().encode($0) }
        self.init(method: method, url: url, accept: .json, body: b, headers: headers, query: query) { data in
            return try? JSONDecoder().decode(A.self, from: data)
        }
    }
}


extension DateFormatter {
    static let iso8601WithTimeZone: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return dateFormatter
    }()
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

extension RemoteEndpoint {
    var promise: Promise<A?> {
        return URLSession.shared.load(self)
    }
}

