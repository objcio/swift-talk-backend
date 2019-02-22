//
//  QueryTests.swift
//  Base
//
//  Created by Chris Eidhof on 22.02.19.
//

import Foundation
import XCTest
import Database
import PostgreSQL

func TAssertEqual(_ lhs: [NodeRepresentable], _ rhs: [NodeRepresentable], file: StaticString = #file, line: UInt = #line) throws {
    try XCTAssertEqual(lhs.map { try $0.makeNode(in: nil) }, rhs.map { try $0.makeNode(in: nil) }, file: file, line: line)
}

class QueryTests: XCTestCase {
    func testSimpleQuery() throws {
        let x: QueryStringAndParams = "SELECT * from users where name=\(param: "test") AND age > \(param: 18)"
        XCTAssertEqual(x.sql, "SELECT * from users where name=$1 AND age > $2")
        XCTAssertEqual(x.values.count, 2)
        try TAssertEqual(x.values, ["test", 18])
    }
    
    func testAppend() throws {
        var x: QueryStringAndParams = "DELETE FROM users WHERE name=\(param: "foo")"
        x.append("AND confirmed=\(param: true)")
        XCTAssertEqual(x.sql, "DELETE FROM users WHERE name=$1 AND confirmed=$2")
        try TAssertEqual(x.values, ["foo", true])
    }
}
