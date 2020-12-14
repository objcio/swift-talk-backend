//
//  TestBase.swift
//  Backtrace
//
//  Created by Chris Eidhof on 05.08.19.
//

import Foundation
import Base
import XCTest

final class TestBase: XCTestCase {
    func testDecodeFormData() {
    	let string = "csrf=92609DB9-935A-4305-BBB4-DFE30474FBEE&name=Chris+Eidhof&email=chris%2B2%40eidhof.nl&commit=Update+Profile"
        let result = string.parseAsQueryPart
        let expected = [
            "csrf": "92609DB9-935A-4305-BBB4-DFE30474FBEE",
            "name": "Chris Eidhof",
            "email": "chris+2@eidhof.nl",
            "commit": "Update Profile"
        ]
        XCTAssertEqual(result, expected)
    }
}
