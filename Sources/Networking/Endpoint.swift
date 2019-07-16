//
//  Endpoint.swift
//  Bits
//
//  Created by Chris Eidhof on 09.08.18.
//

import Foundation
import TinyNetworking

public let defaultTimeOutInterval: TimeInterval = 30
public protocol URLSessionProtocol {
    @discardableResult
    func load<A>(_ e: Endpoint<A>, onComplete: @escaping (Result<A, Error>) -> ()) -> URLSessionDataTask
    func onDelegateQueue(_ f: @escaping () -> ())
}

extension URLSession: URLSessionProtocol {}
