//
//  RequestEnvironment.swift
//  Bits
//
//  Created by Chris Eidhof on 14.12.18.
//

import Foundation
import Base
import Database

public protocol RequestEnvironment {
    associatedtype S
    var session: S? { get }
    var csrf: CSRFToken { get }
    func execute<A>(_ query: Query<A>) -> Either<A, Error>
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

