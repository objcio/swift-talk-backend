import XCTest

import vimeoTests

var tests = [XCTestCaseEntry]()
tests += vimeoTests.allTests()
XCTMain(tests)