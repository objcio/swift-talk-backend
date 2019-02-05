//
//  RequestEnvironment.swift
//  Bits
//
//  Created by Chris Eidhof on 14.12.18.
//

import Foundation
import Base
import Database

typealias STRequestEnvironment = RequestEnvironment<Route, Session>

struct RequestEnvironment<R: RouteP, S: SessionP> {
    var hashedAssetName: (String) -> String = { $0 }
    let route: R
    let resourcePaths: [URL]
    var session: S? { return flatten(try? _session.get()) }
    
    private let _connection: Lazy<ConnectionProtocol>
    private let _session: Lazy<S?>

    init(route: R, hashedAssetName: @escaping (String) -> String, buildSession: @escaping () -> S?, connection: Lazy<ConnectionProtocol>, resourcePaths: [URL]) {
        self.hashedAssetName = hashedAssetName
        self._session = Lazy(buildSession, cleanup: { _ in () })
        self.route = route
        self._connection = connection
        self.resourcePaths = resourcePaths
    }
    
    var context: Context<R, S> {
        return Context(route: route, message: nil, session: session)
    }
    
    func connection() throws -> ConnectionProtocol {
        return try _connection.get()
    }
}
