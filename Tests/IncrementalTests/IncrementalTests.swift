import Foundation
import XCTest
import Incremental

func &&(lhs: Observable<Bool>, rhs: Observable<Bool>) -> Observable<Bool> {
    return lhs.flatMap { x in rhs.map { $0 && x } }
}

final class IncrementalTests: XCTestCase {
    func testFlatMapNested() {
        let o = Observable(0)
        let o2 = o.flatMap { _ in o }
        var results: [Int] = []
        o2.observe { results.append($0) }
        o.send(1) // eventually crashes here
        XCTAssert(results == [0, 1])
    }
    
    func testFlatMapMap() {
        let x = Observable(1)
        let double = x.flatMap { value in x.map { value + $0 }}
        var result: [Int] = []
        let disposable = double.observe { result.append($0) }
        x.send(2)
        XCTAssertEqual(result, [2,4])
    }
    
    func test() {
        let airplaneMode = Observable<Bool>(false)
        let cellular = Observable<Bool>(true)
        let wifi = Observable<Bool>(true)
        
        let notAirplaneMode = airplaneMode.map { !$0 }
        
        let cellularEnabled = notAirplaneMode && cellular
        let wifiEnabled = notAirplaneMode && wifi
        let wifiAndCellular = wifiEnabled && cellularEnabled
        
        var results: [Bool] = []
        _ = wifiAndCellular.observe { results.append($0) }
        airplaneMode.send(true)
        airplaneMode.send(false)
        XCTAssertEqual(results, [true,false,true])
    }
}
