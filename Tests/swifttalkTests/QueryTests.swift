//
//  QueryTests.swift
//  Base
//
//  Created by Chris Eidhof on 22.02.19.
//

import Foundation
import XCTest
import Database
import LibPQ

func TAssertEqual(_ lhs: [Param], _ rhs: [Param], file: StaticString = #file, line: UInt = #line) throws {
    XCTAssertEqual(lhs.map { $0.stringValue }, rhs.map { $0.stringValue }, file: file, line: line)
}

class QueryTests: XCTestCase {
    func testSimpleQuery() throws {
        let x: QueryStringAndParams = "SELECT * from users where name=\(param: "test") AND age > \(param: 18)"
        XCTAssertEqual(x.rendered.sql, "SELECT * from users where name= $1  AND age >  $2 ")
        XCTAssertEqual(x.rendered.values.count, 2)
        try TAssertEqual(x.rendered.values, ["test", 18])
    }
    
    func testAppend() throws {
        var x: QueryStringAndParams = "DELETE FROM users WHERE name=\(param: "foo")"
        x.append("AND confirmed=\(param: true)")
        XCTAssertEqual(x.rendered.sql, "DELETE FROM users WHERE name= $1 AND confirmed= $2 ")
        try TAssertEqual(x.rendered.values, ["foo", true])
    }
}
