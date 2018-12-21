//
//  Routes.swift
//  Bits
//
//  Created by Chris Eidhof on 21.12.18.
//

import Foundation
import XCTest
@testable import SwiftTalkServerLib

final class RouteTests: XCTestCase {
    
    override static func setUp() {
	}
    
    func testBasicRoutes() {
        XCTAssertEqual(Route.init(Request("/episodes/S01E132-dijkstra-s-shortest-path-algorithm")), Route.episode(Id(rawValue: "S01E132-dijkstra-s-shortest-path-algorithm"), .view(playPosition: nil)))
        XCTAssertEqual(Route.init(Request("/collections/map-routing")), Route.collection(Id(rawValue: "map-routing")))
    }
}
