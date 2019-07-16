//
//  Network.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import Networking
import Promise
import Base
import TinyNetworking

extension Endpoint {
    var promise: Promise<A?> {
        return globals.urlSession.load(self)
    }
}

extension URLSessionProtocol {
    func load<A>(_ e: Endpoint<A>) -> Promise<A?> {
        return Promise { cb in
            self.load(e, callback: cb)
        }
    }

    func load<A>(_ e: Endpoint<A>, callback: @escaping (A?) -> ()) {
        load(e, onComplete: { result in
            switch result {
            case .failure(let err):
                log(error: "request failed: \(String(describing: e))\nerror:\(String(describing: err))")
                callback(nil)
            case .success(let r):
                callback(r)
            }
        })
    }

    func load<A>(_ e: CombinedEndpoint<A>, callback: @escaping (A?) -> ()) {
        load(e, onComplete: { result in
            switch result {
            case .failure(let err):
                log(error: "request failed: \(String(describing: e))\nerror:\(String(describing: err))")
                callback(nil)
            case .success(let r):
                callback(r)
            }
        })
    }
}

