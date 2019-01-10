//
//  Promise.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 29-11-2018.
//

import Foundation


public struct Promise<A> {
    public let run: (@escaping (A) -> ()) -> ()
    public init(_ run: @escaping ((@escaping (A) -> ()) -> ())) {
        self.run = run
    }
    
    public func map<B>(_ f: @escaping (A) -> B) -> Promise<B> {
        return Promise<B> { cb in
            self.run { a in
                cb(f(a))
            }
        }
    }
    
    public func flatMap<B>(_ f: @escaping (A) -> Promise<B>) -> Promise<B> {
        return Promise<B> { cb in
            self.run { a in
                let p = f(a)
                p.run(cb)
            }
        }
    }
}

func zip<A,B>(_ p0: Promise<A>, _ p1: Promise<B>) -> Promise<(A,B)> {
    return Promise<(A,B)> { cb in
        let values = Atomic<(A?, B?)>((nil, nil), didSet: {
            guard let x = $0.0, let y = $0.1 else { return }
            cb((x,y))
        })
        p0.run { p0_val in
           values.mutate({ $0.0 = p0_val})
        }
        p1.run { p1_val in
            values.mutate({ $0.1 = p1_val })
        }
    }
}

func zip<A,B,C>(
    _ p0: Promise<A>,
    _ p1: Promise<B>,
    _ p2: Promise<C>) -> Promise<(A,B,C)> {
    return zip(p0, zip(p1, p2)).map { ($0.0, $0.1.0, $0.1.1) }
}

func zip<A,B,C,D>(
    _ p0: Promise<A>,
    _ p1: Promise<B>,
    _ p2: Promise<C>,
    _ p3: Promise<D>
    ) -> Promise<(A,B,C, D)> {
    return zip(p0, zip(p1, zip(p2, p3))).map { ($0.0, $0.1.0, $0.1.1.0, $0.1.1.1) }
}

func zip<A,B,C,D,E>(
    _ p0: Promise<A>,
    _ p1: Promise<B>,
    _ p2: Promise<C>,
    _ p3: Promise<D>,
    _ p4: Promise<E>
    ) -> Promise<(A,B,C, D, E)> {
    return zip(p0, zip(p1, zip(p2, zip(p3, p4)))).map { ($0.0, $0.1.0, $0.1.1.0, $0.1.1.1.0, $0.1.1.1.1) }
}

func zip<A,B,C,D,E,F>(
    _ p0: Promise<A>,
    _ p1: Promise<B>,
    _ p2: Promise<C>,
    _ p3: Promise<D>,
    _ p4: Promise<E>,
    _ p5: Promise<F>
    ) -> Promise<(A,B,C, D, E, F)> {
    return zip(p0, zip(p1, zip(p2, zip(p3, zip(p4, p5))))).map { ($0.0, $0.1.0, $0.1.1.0, $0.1.1.1.0, $0.1.1.1.1.0, $0.1.1.1.1.1) }
}
