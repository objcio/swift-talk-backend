//
//  TestHelpers.swift
//  SwiftTalkTests
//
//  Created by Chris Eidhof on 18.12.18.
//

import Foundation
import Promise
import Base
import XCTest
import LibPQ
import NIOWrapper
import HTML1
import Database
import WebServer
import TinyNetworking
@testable import Networking
@testable import SwiftTalkServerLib

enum TestInterpreter: NIOWrapper.Response, WebServer.Response, WebServer.ResponseRequiringEnvironment, FailableResponse {
    typealias Env = STRequestEnvironment
    
    case _write(String, status: HTTPResponseStatus, headers: [String:String])
    case _writeData(Data, status: HTTPResponseStatus, headers: [String:String])
    case _writeFile(path: String, maxAge: UInt64?)
    case _redirect(path: String, headers: [String:String])
    case _onComplete(promise: Promise<Any>, do: (Any) -> TestInterpreter)
    case _withPostData(do: (Data) -> TestInterpreter)
    
    case _writeHTML(HTML1.Node<()>, status: HTTPResponseStatus)
    
    case _withCSRF(cont: (CSRFToken) -> TestInterpreter)
    case _execute(Query<Any>, cont: (Either<Any, Error>) -> TestInterpreter)
    case _withSession(cont: (Session?) -> TestInterpreter)

    static func write(_ string: String, status: HTTPResponseStatus, headers: [String : String]) -> TestInterpreter {
        return ._write(string, status: status, headers: headers)
    }
    
    static func write(_ data: Data, status: HTTPResponseStatus, headers: [String : String]) -> TestInterpreter {
        return ._writeData(data, status: status, headers: headers)
    }
    
    static func writeFile(path: String, maxAge: UInt64?) -> TestInterpreter {
        return ._writeFile(path: path, maxAge: maxAge)
    }
    
    static func redirect(path: String, headers: [String : String]) -> TestInterpreter {
        return ._redirect(path: path, headers: headers)
    }
    
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> TestInterpreter) -> TestInterpreter {
        return ._onComplete(promise: promise.map { $0 }, do: { x in cont(x as! A) })
    }
    
    static func withPostData(do cont: @escaping (Data) -> TestInterpreter) -> TestInterpreter {
        return ._withPostData(do: cont)
    }
    
    static func write(html: HTML1.Node<()>, status: HTTPResponseStatus) -> TestInterpreter {
        return ._writeHTML(html, status: status)
    }

    static func withCSRF(_ cont: @escaping (CSRFToken) -> TestInterpreter) -> TestInterpreter {
        return ._withCSRF(cont: cont)
    }
    
    static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) -> TestInterpreter) -> TestInterpreter {
        return ._execute(query.map { $0 }, cont: { x in cont(x as! Either<A, Error>) })
    }
    
    static func withSession(_ cont: @escaping (Session?) -> TestInterpreter) -> TestInterpreter {
        return ._withSession(cont: cont)
    }

    static func renderError(_ error: Error) -> TestInterpreter {
        fatalError()
    }
}

extension TestInterpreter {
    func linkTargets(file: StaticString = #file, line: UInt = #line) -> [Route] {
        guard case let ._writeHTML(node, status: .ok) = self else { XCTFail("Expected HTML", file: file, line: line); return [] }
        return node.linkTargets().compactMap( { Route(Request($0))})
    }
    
    func forms(file: StaticString = #file, line: UInt = #line) -> [(action: Route, inputs: [(String,String)])] {
        guard case let ._writeHTML(node, status: .ok) = self else { XCTFail("Expected HTML", file: file, line: line); return [] }
        return node.forms().compactMap { (a, inputs) in
            guard let action = Route(Request(a)) else { return nil }
            return (action, inputs)
        }
    }
    
    func testIsError(file: StaticString = #file, line: UInt = #line) {
        guard case let ._writeHTML(_, status: status) = self else { XCTFail("Expected HTML", file: file, line: line); return }
        XCTAssert(status.code >= 400, file: file, line: line)
    }
}

func testLinksTo(_ i: TestInterpreter, route: Route, file: StaticString = #file, line: UInt = #line) {
    let routes = i.linkTargets()
    XCTAssert(routes.contains { $0 == route }, "Expected \(route) in \(routes)", file: file, line: line)
}


func TestUnwrap<A>(_ value: A?, file: StaticString = #file, line: UInt = #line) throws -> A {
    guard let x = value else {
        XCTFail(file: file, line: line)
        throw TestErr()
    }
    return x
}


class TestConnection: ConnectionProtocol {
    let _execute: (String, [Param]) -> QueryResult = { _,_ in fatalError() }
    private var results: [QueryAndResult]
    
    init(_ results: [QueryAndResult] = []) {
        self.results = results
    }
    
    func execute(_ query: String, _ values: [Param]) throws -> QueryResult {
        return _execute(query, values)
    }
    
    func execute<A>(_ query: Query<A>) throws -> A {
        guard let idx = results.firstIndex(where: { $0.query.matches(query) }) else { XCTFail("Query not found: \(query)"); throw TestErr() }
        let response = results[idx].response as! A
        results.remove(at: idx)
        return response
    }
    
    func close() {
    }
    
    func assertDone() {
        XCTAssert(results.isEmpty)
    }
    
    var lazy: Lazy<ConnectionProtocol> {
        return Lazy({ self }, cleanup: { _ in })
    }
}

struct TestErr: Error { }

extension Query {
    func matches<B>(_ other: Query<B>) -> Bool {
        if query.rendered.sql == other.query.rendered.sql {
            let v1 = query.rendered.values.map { $0.stringValue }
            let v2 = other.query.rendered.values.map { $0.stringValue }
            guard v1.count == v2.count else { return false }
            for (x, y) in zip(v1, v2) {
                guard x == y else { return false }
            }
            return true
        }
        return false
    }
}

struct EndpointAndResult {
    let endpoint: Endpoint<Any>
    let response: Any?
    init<A>(endpoint: Endpoint<A>, response: A?) {
        self.endpoint = endpoint.map { $0 }
        self.response = response
    }
}

class TestURLSession: URLSessionProtocol {
    private var results: [EndpointAndResult]
    
    init(_ results: [EndpointAndResult]) {
        self.results = results
    }
    
    func load<A>(_ endpoint: Endpoint<A>, onComplete: @escaping (Result<A, Error>) -> ()) -> URLSessionDataTask {
        guard let idx = results.firstIndex(where: { $0.endpoint.request.matches(endpoint.request) }) else {
            XCTFail("Unexpected endpoint: \(endpoint.request.httpMethod ?? "GET") \(endpoint.request.url!)")
            return URLSessionDataTask()
        }
        if let response = results[idx].response as! A? {
            onComplete(.success(response))
        } else {
            onComplete(.failure(UnknownError()))
        }
        results.remove(at: idx)
        return URLSessionDataTask()
    }
    
    func assertDone() {
        XCTAssert(results.isEmpty)
    }
    
    func onDelegateQueue(_ f: @escaping () -> ()) {
        f()
    }
}

extension URLRequest {
    func matches(_ other: URLRequest) -> Bool {
        return url == other.url && httpMethod == other.httpMethod && allHTTPHeaderFields == other.allHTTPHeaderFields && httpBody == other.httpBody
    }
}

