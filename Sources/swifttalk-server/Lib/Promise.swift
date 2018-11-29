//
//  Promise.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 29-11-2018.
//

import Foundation


struct Promise<A> {
    public let run: (@escaping (A) -> ()) -> ()
    init(_ run: @escaping ((@escaping (A) -> ()) -> ())) {
        self.run = run
    }
    
    func map<B>(_ f: @escaping (A) -> B) -> Promise<B> {
        return Promise<B> { cb in
            self.run { a in
                cb(f(a))
            }
        }
    }
    
    func flatMap<B>(_ f: @escaping (A) -> Promise<B>) -> Promise<B> {
        return Promise<B> { cb in
            self.run { a in
                let p = f(a)
                p.run(cb)
            }
        }
    }
}

func sequentially<A>(_ promises: [Promise<A>]) -> Promise<[A]> {
    let initial: Promise<[A]> = Promise { $0([]) }
    return promises.reduce(initial) { result, promise in
        return result.flatMap { (existing: [A]) in
            promise.map { new in
                return existing + [new]
            }
        }
    }
}

