//
//  Endpoint.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation
import XMLParsing

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
    
    init(get: URL, accept: Accept? = nil, headers: [String:String] = [:], query: [String:String], parse: @escaping (Data) -> A?) {
        var comps = URLComponents(string: get.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        if let a = accept {
            request.setValue(a.rawValue, forHTTPHeaderField: "Accept")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
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
    
    func map<B>(_ f: @escaping (A) -> B) -> RemoteEndpoint<B> {
        return RemoteEndpoint<B>(request: request, parse: { value in
            self.parse(value).map(f)
        })
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
    
    init(get: URL, accept: Accept = .json, headers: [String:String] = [:], query: [String:String] = [:]) {
        switch accept {
        case .json:
            self.init(get: get, accept: accept, headers: headers, query: query, parse: { data in
                return try? JSONDecoder().decode(A.self, from: data)
            })
        case .xml:
            self.init(get: get, accept: accept, headers: headers, query: query, parse: { data in
//                print(String(data: data, encoding: .utf8)!)
                let decoder = XMLDecoder.init()
                decoder.dateDecodingStrategy =  XMLDecoder.DateDecodingStrategy.formatted(DateFormatter.iso8601WithTimeZone) // todo: should this be a parameter?
                do {
                	return try decoder.decode(A.self, from: data)
                } catch {
                    print("Decoding error: \(error), \(error.localizedDescription)", to: &standardError)
                    return nil
                }
            })
        }
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

