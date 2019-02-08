//
//  RequestEnvironment.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 08-02-2019.
//

import Foundation
import Base
import Database
import WebServer

private let sharedCSRF = CSRFToken(UUID(uuidString: "F5F6C2AE-85CB-4989-B0BF-F471CC92E3FF")!)

public struct STRequestEnvironment: RequestEnvironment {
    var hashedAssetName: (String) -> String = { $0 }
    var resourcePaths: [URL]
    public var route: Route
    public var session: Session? { return flatten(try? _session.get()) }
    
    private let _connection: Lazy<ConnectionProtocol>
    private let _session: Lazy<S?>
    
    public init(route: Route, hashedAssetName: @escaping (String) -> String, buildSession: @escaping () -> S?, connection: Lazy<ConnectionProtocol>, resourcePaths: [URL]) {
        self.hashedAssetName = hashedAssetName
        self._session = Lazy(buildSession, cleanup: { _ in () })
        self.route = route
        self._connection = connection
        self.resourcePaths = resourcePaths
    }
    
    public var csrf: CSRFToken {
        return session?.user.data.csrfToken ?? sharedCSRF
    }
    
    public func execute<A>(_ query: Query<A>) -> Either<A, Error> {
        do {
            return try .left(_connection.get().execute(query))
        } catch {
            return .right(error)
        }
    }
}


