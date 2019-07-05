//
//  Postgres.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import LibPQ
import Base

public struct Postgres {
    // private let connection: Connection
    private let connectionInfo: URL
    
    public init(url: URL) {
//        let connInfo = ConnInfo.raw(url)
//        postgreSQL = try! PostgreSQL.Database(connInfo: connInfo)
        connectionInfo = url
    }

    public init(host: String, port: Int = 5432, name: String, user: String, password: String) {
        let url = URL(string: "postgresql://\(user):\(password)@\(host):\(port)/\(name)")!
        self.init(url: url)
    }
    
    public func withConnection<A>(_ x: (ConnectionProtocol) throws -> A) throws -> A {
        let conn = try Connection(connectionInfo: connectionInfo)
        let result = try x(conn)
        conn.close()
        return result
    }
    
    public func lazyConnection() -> Lazy<ConnectionProtocol> {
        return Lazy<ConnectionProtocol>({ () throws -> ConnectionProtocol in
            return try Connection(connectionInfo: self.connectionInfo)
        }, cleanup: { conn in
            conn.close()
        })
    }
}

public struct DatabaseError: Error, LocalizedError {
    let err: Error
    let query: String
    
    public init(err: Error, query: String) {
        self.err = err
        self.query = query
    }
    
    public var errorDescription: String? {
        return "\(err), query: \(query)"
    }
}

public protocol ConnectionProtocol {
    func execute(_ query: String, _ values: [Param]) throws -> QueryResult
    func execute<A>(_ query: Query<A>) throws -> A
    func close()
}

extension ConnectionProtocol {
    public func execute(_ query: String) throws -> QueryResult {
        return try execute(query, [])
    }
}

extension Connection: ConnectionProtocol { }

public struct FieldValues {
    private var _fields: [(name: String, value: Param)]
    
    init(_ fields: [(name: String, value: Param)]) {
        self._fields = fields
    }
    
    var fields: [String] {
        return _fields.map { $0.name }
    }
    
    public var fieldList: String {
        return fields.sqlJoined
    }
    
    var values: [Param] {
        return _fields.map { $0.value }
    }
}

extension Encodable {
    public var fieldValues: FieldValues {
        let m = Mirror(reflecting: self)
        let children = Array(m.children)
        let names = children.map { $0.label!.snakeCased }
        let values = children.map { ($0.value as! Param) }
        return FieldValues(Array(zip(names, values)))
    }
}

extension Decodable {
    private static var fieldNames: [String] {
        return try! PropertyNamesDecoder.decode(Self.self).map { $0.snakeCased }
    }
    
    public static func fieldList(_ transform: (String) -> String = { $0 }) -> String {
        return fieldNames.map(transform).sqlJoined
    }
}

extension Connection {
    @discardableResult
    public func execute<A>(_ query: Query<A>) throws -> A {
        return try execute(query, loggingThreshold: 0.1)
    }
    
    @discardableResult
    func execute<A>(_ query: Query<A>, loggingThreshold: TimeInterval) throws -> A {
        //        print(query.query)
        let node = try measure(message: "query: \(query.query)", threshold: loggingThreshold) { () throws -> QueryResult in
            do {
                return try execute(query.query, query.values)
            } catch {
                throw DatabaseError(err: error, query: query.query)
            }
        }
        return query.parse(node)
    }
}


