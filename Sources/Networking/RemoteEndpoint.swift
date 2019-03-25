//
//  Endpoint.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation

public enum ContentType: String {
    case json = "application/json"
    case xml = "application/xml"
}

public func expected200to300(_ code: Int) -> Bool {
    return code >= 200 && code < 300
}

public struct RemoteEndpoint<A> {
    public enum Method {
        case get, post, put, patch
    }
    
    var request: URLRequest
    var parse: (Data?) -> A?
    var expectedStatusCode: (Int) -> Bool = expected200to300
    
    public func map<B>(_ f: @escaping (A) -> B) -> RemoteEndpoint<B> {
        return RemoteEndpoint<B>(request: request, expectedStatusCode: expectedStatusCode, parse: { value in
            self.parse(value).map(f)
        })
    }

    public func compactMap<B>(_ transform: @escaping (A) -> B?) -> RemoteEndpoint<B> {
        return RemoteEndpoint<B>(request: request, expectedStatusCode: expectedStatusCode, parse: { data in
            self.parse(data).flatMap(transform)
        })
    }

    public init(_ method: Method, url: URL, accept: ContentType? = nil, contentType: ContentType? = nil, body: Data? = nil, headers: [String:String] = [:], expectedStatusCode: @escaping (Int) -> Bool, timeOutInterval: TimeInterval = 10, query: [String:String] = [:], parse: @escaping (Data?) -> A?) {
        var comps = URLComponents(string: url.absoluteString)!
        comps.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
        request = URLRequest(url: comps.url!)
        if let a = accept {
            request.setValue(a.rawValue, forHTTPHeaderField: "Accept")
        }
        if let ct = contentType {
            request.setValue(ct.rawValue, forHTTPHeaderField: "Content-Type")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.timeoutInterval = timeOutInterval
        request.httpMethod = method.string

        // body *needs* to be the last property that we set, because of this bug: https://bugs.swift.org/browse/SR-6687
        request.httpBody = body

        self.expectedStatusCode = expectedStatusCode
        self.parse = { $0.flatMap(parse) }
    }
    
    public init(request: URLRequest, expectedStatusCode: @escaping (Int) -> Bool, parse: @escaping (Data?) -> A?) {
        self.request = request
        self.expectedStatusCode = expectedStatusCode
        self.parse = parse
    }
}

extension RemoteEndpoint: CustomStringConvertible {
    public var description: String {
        let data = request.httpBody ?? Data()
        return "\(request.httpMethod ?? "GET") \(request.url) \(String(data: data, encoding: .utf8) ?? "")"
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
    public init(_ method: Method, url: URL, accept: ContentType? = nil, headers: [String:String] = [:], expectedStatusCode: @escaping (Int) -> Bool = expected200to300, query: [String:String] = [:]) {
        self.init(method, url: url, accept: accept, headers: headers, expectedStatusCode: expectedStatusCode, query: query, parse: { _ in () })
    }

    public init<B: Codable>(json method: Method, url: URL, accept: ContentType? = .json, body: B, headers: [String:String] = [:], expectedStatusCode: @escaping (Int) -> Bool = expected200to300, query: [String:String] = [:]) {
        let b = try! JSONEncoder().encode(body)
        self.init(method, url: url, accept: accept, contentType: .json, body: b, headers: headers, expectedStatusCode: expectedStatusCode, query: query, parse: { _ in () })
    }
}

extension RemoteEndpoint where A: Decodable {
    public init(json method: Method, url: URL, accept: ContentType = .json, headers: [String: String] = [:], expectedStatusCode: @escaping (Int) -> Bool = expected200to300, query: [String: String] = [:], decoder: JSONDecoder? = nil) {
        let d = decoder ?? JSONDecoder()
        self.init(method, url: url, accept: accept, body: nil, headers: headers, expectedStatusCode: expectedStatusCode, query: query) { data in
            guard let dat = data else { return nil }
            return try? d.decode(A.self, from: dat)
        }
    }

    public init<B: Codable>(json method: Method, url: URL, accept: ContentType = .json, body: B? = nil, headers: [String: String] = [:], expectedStatusCode: @escaping (Int) -> Bool = expected200to300, query: [String: String] = [:]) {
        let b = body.map { try! JSONEncoder().encode($0) }
        self.init(method, url: url, accept: accept, contentType: .json, body: b, headers: headers, expectedStatusCode: expectedStatusCode, query: query) { data in
            guard let dat = data else { return nil }
            return try? JSONDecoder().decode(A.self, from: dat)
        }
    }
}

public protocol URLSessionProtocol {
    func load<A>(_ e: RemoteEndpoint<A>, failure: @escaping (Error?, URLResponse?) -> (), onComplete: @escaping (A?) -> ())
    func onDelegateQueue(_ f: @escaping () -> ())
}

extension URLSession: URLSessionProtocol {}

extension URLSession {
    public func load<A>(_ e: RemoteEndpoint<A>, failure: @escaping (Error?, URLResponse?) -> (), onComplete: @escaping (A?) -> ()) {
        let r = e.request
        dataTask(with: r, completionHandler: { data, resp, err in
            guard let h = resp as? HTTPURLResponse, e.expectedStatusCode(h.statusCode) else {
                failure(err, resp); return
            }
            onComplete(e.parse(data))
        }).resume()
    }

    public func onDelegateQueue(_ f: @escaping () -> ()) {
        self.delegateQueue.addOperation(f)
    }
}

