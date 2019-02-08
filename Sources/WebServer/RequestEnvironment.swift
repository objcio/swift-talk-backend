//
//  RequestEnvironment.swift
//  Bits
//
//  Created by Chris Eidhof on 14.12.18.
//

import Foundation
import Base
import Database

public protocol RouteP {
    var path: String { get }
}

public protocol SessionP {
    var csrf: CSRFToken { get }
}

public struct CSRFToken: Codable, Equatable, Hashable {
    public var value: UUID
    
    public init(_ uuid: UUID) {
        self.value = uuid
    }
    
    public init(from decoder: Decoder) throws {
        self.init(try UUID(from: decoder))
    }
    
    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
    public var stringValue: String {
        return value.uuidString
    }
}

public struct RequestEnvironment<R: RouteP, S: SessionP> {
    public var hashedAssetName: (String) -> String = { $0 }
    let route: R
    public let resourcePaths: [URL]
    var session: S? { return flatten(try? _session.get()) }
    
    private let _connection: Lazy<ConnectionProtocol>
    private let _session: Lazy<S?>

    public init(route: R, hashedAssetName: @escaping (String) -> String, buildSession: @escaping () -> S?, connection: Lazy<ConnectionProtocol>, resourcePaths: [URL]) {
        self.hashedAssetName = hashedAssetName
        self._session = Lazy(buildSession, cleanup: { _ in () })
        self.route = route
        self._connection = connection
        self.resourcePaths = resourcePaths
    }
    
    public var context: Context<R, S> {
        return Context(route: route, message: nil, session: session)
    }
    
    func connection() throws -> ConnectionProtocol {
        return try _connection.get()
    }
}

extension RequestEnvironment {
    func execute<A>(_ query: Query<A>) -> Either<A, Error> {
        do {
            return try .left(connection().execute(query))
        } catch {
            return .right(error)
        }
    }
    
    @available(*, deprecated)
    func getConnection() -> Either<ConnectionProtocol, Error> {
        do { return try .left(connection()) }
        catch { return .right(error) }
    }
}

public enum FlashType {
    case notice
    case alert
}

public struct Context<R, S: SessionP> {
    public var route: R
    public var message: (String, FlashType)?
    public var session: S?
    
    public var csrf: CSRFToken {
        return session?.csrf ?? sharedCSRF
    }
}

private let sharedCSRF = CSRFToken(UUID(uuidString: "F5F6C2AE-85CB-4989-B0BF-F471CC92E3FF")!)

