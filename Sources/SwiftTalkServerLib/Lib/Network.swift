//
//  Network.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import Networking
import Promise


extension RemoteEndpoint {
    var promise: Promise<A?> {
        return globals.urlSession.load(self)
    }
}

extension URLSessionProtocol {
    func load<A>(_ e: RemoteEndpoint<A>) -> Promise<A?> {
        return Promise { cb in
            self.load(e, callback: cb)
        }
    }

    func load<A>(_ e: RemoteEndpoint<A>, callback: @escaping (A?) -> ()) {
        load(e, failure: { err, resp in
            log(error: "request failed: \(String(describing: e))\nerror:\(String(describing: err))\nresponse: \(String(describing: resp))")
            callback(nil)
        }, onComplete: { result in
            callback(result)
        })
    }

    func load<A>(_ e: CombinedEndpoint<A>, callback: @escaping (A?) -> ()) {
        load(e, failure: { err, resp in
            log(error: "request failed: \(String(describing: e))\nerror:\(String(describing: err))\nresponse: \(String(describing: resp))")
            callback(nil)
        }, onComplete: { result in
            callback(result)
        })
    }
}

