//
//  CombinedEndpoint.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 10-01-2019.
//

import Foundation
import TinyNetworking

public indirect enum CombinedEndpoint<A> {
    case single(Endpoint<A>)
    case _sequence(CombinedEndpoint<Any>, (Any) -> CombinedEndpoint<A>?)
    case _zipped(CombinedEndpoint<Any>, CombinedEndpoint<Any>, (Any, Any) -> A)
}

extension CombinedEndpoint {
    var asAny: CombinedEndpoint<Any> {
        switch self {
        case let .single(r): return .single(r.map { $0 })
        case let ._sequence(l, transform): return ._sequence(l, { x in
            transform(x)?.asAny
        })
        case let ._zipped(l, r, f): return ._zipped(l, r, { x, y in
            f(x, y)
        })
        }
    }
    
    public func flatMap<B>(_ transform: @escaping (A) -> CombinedEndpoint<B>?) -> CombinedEndpoint<B> {
        return CombinedEndpoint<B>._sequence(self.asAny, { x in
            transform(x as! A)
        })
    }
    
    public func map<B>(_ transform: @escaping (A) -> B) -> CombinedEndpoint<B> {
        switch self {
        case let .single(r): return .single(r.map(transform))
        case let ._sequence(l, f):
            return ._sequence(l, { x in
                f(x)?.map(transform)
            })
        case let ._zipped(l, r, f):
            return CombinedEndpoint<B>._zipped(l, r, { x, y in
                transform(f(x, y))
            })
        }
    }
    
    public func zipWith<B, C>(_ other: CombinedEndpoint<B>, _ combine: @escaping (A,B) -> C) -> CombinedEndpoint<C> {
        return CombinedEndpoint<C>._zipped(self.asAny, other.asAny, { x, y in
            combine(x as! A, y as! B)
        })
    }
    
    public func zip<B>(_ other: CombinedEndpoint<B>) -> CombinedEndpoint<(A,B)> {
        return zipWith(other, { ($0, $1) })
    }
}

public func zip<A>(_ endpoints: [CombinedEndpoint<A>]) -> CombinedEndpoint<[A]>? {
    guard let initial = endpoints.first?.map({ [$0] }) else { return nil }
    return endpoints.dropFirst().reduce(initial) { result, endpoint in
        result.zip(endpoint).map { $0.0 + [$0.1] }
    }
}

public func sequentially<A>(_ endpoints: [CombinedEndpoint<A>]) -> CombinedEndpoint<[A]>? {
    guard let initial = endpoints.first?.map({ [$0] }) else { return nil }
    return endpoints.dropFirst().reduce(initial) { result, endpoint in
        result.flatMap { acc in
            endpoint.map { acc + [$0] }
        }
    }
}

extension Result {
    func getError() -> Failure? {
        switch self {
        case .failure(let f): return f
        default: return nil
        }
    }
}

extension URLSessionProtocol {
    public func load<A>(_ endpoint: CombinedEndpoint<A>, onComplete: @escaping (Result<A, Error>) -> ()) {
        switch endpoint {
        case let .single(r):
            load(r, onComplete: onComplete)
        case let ._sequence(l, transform):
            load(l) { result in
                switch result {
                case .failure(let f): onComplete(.failure(f))
                case .success(let s):
                    guard let next = transform(s) else {
                        onComplete(Result<A, Error>.failure(UnknownError()))
                        return
                    }
                	self.load(next, onComplete: onComplete)
                }                
            }
        case let ._zipped(l, r, transform):
            let group = DispatchGroup()
            var resultA: Result<Any, Error>?
            var resultB: Result<Any, Error>?
            group.enter()
            group.enter()
            load(l) {
                resultA = $0
                group.leave()
            }
            load(r) {
                resultB = $0
                group.leave()
            }
            group.notify(queue: .global()) {
                self.onDelegateQueue {
                    guard let x = try? resultA?.get(), let y = try? resultB?.get() else {
                        onComplete(.failure(resultA?.getError() ?? resultB?.getError() ?? UnknownError()))
                        return
                    }
                    onComplete(.success(transform(x, y)))
                }
            }
        }
    }
}

extension Endpoint {
    public var c: CombinedEndpoint<A> {
        return .single(self)
    }
}
