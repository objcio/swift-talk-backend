
import XCTest
import NIOHTTP1
@testable import SwiftTalkServerLib

enum TestInterpreter: Interpreter {
    case _write(String, status: HTTPResponseStatus, headers: [String:String])
    case _writeData(Data, status: HTTPResponseStatus, headers: [String:String])
    case _writeFile(path: String, maxAge: UInt64?)
    case _onComplete(promise: Promise<Any>, do: (Any) -> TestInterpreter)
    case _withPostData(do: (Data) -> TestInterpreter)
    case _redirect(path: String, headers: [String:String])

    static func write(_ string: String, status: HTTPResponseStatus, headers: [String : String]) -> TestInterpreter {
        return ._write(string, status: status, headers: headers)
    }

    static func write(_ data: Data, status: HTTPResponseStatus, headers: [String : String]) -> TestInterpreter {
        return ._writeData(data, status: status, headers: headers)
    }

    static func writeFile(path: String, maxAge: UInt64?) -> TestInterpreter {
        return ._writeFile(path: path, maxAge: maxAge)
    }

    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> TestInterpreter) -> TestInterpreter {
        return ._onComplete(promise: promise.map { $0 }, do: { x in cont(x as! A) })
    }

    static func withPostData(do cont: @escaping (Data) -> TestInterpreter) -> TestInterpreter {
        return ._withPostData(do: cont)
    }

    static func redirect(path: String, headers: [String : String]) -> TestInterpreter {
        return ._redirect(path: path, headers: headers)
    }


}

final class FlowTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssert(Env.init() != nil)
        XCTAssertEqual("X", "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
