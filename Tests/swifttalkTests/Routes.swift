//
//  Routes.swift
//  Bits
//
//  Created by Chris Eidhof on 21.12.18.
//

import Foundation
import XCTest
import Base
@testable import SwiftTalkServerLib

final class RouteTests: XCTestCase {
    
    override static func setUp() {
	}
    
    func testLandingPages() {
        XCTAssertEqual(Route.init(Request("/episodes/S01E132-dijkstra-s-shortest-path-algorithm")), Route.episode(Id(rawValue: "S01E132-dijkstra-s-shortest-path-algorithm"), .view(playPosition: nil)))
        XCTAssertEqual(Route.init(Request("/episodes/S01E126-rendering-tracks?t=100")), Route.episode(Id(rawValue: "S01E126-rendering-tracks"), .view(playPosition: 100)))
        XCTAssertEqual(Route.init(Request("/collections/map-routing")), Route.collection(Id(rawValue: "map-routing")))
        XCTAssertEqual(Route.init(Request("/promo/hello-world")), Route.signup(.promoCode("hello-world")))
        XCTAssertEqual(Route.init(Request("/gift")), Route.gift(.home))
        XCTAssertEqual(Route.init(Request("/")), Route.home)
        XCTAssertEqual(Route.init(Request("/hooks/recurly/123")), Route.webhook(.recurlyWebhook("123")))
        XCTAssertEqual(Route.init(Request("/hooks/github")), Route.webhook(.githubWebhook))
        XCTAssertEqual(Route.init(Request("/users/auth/github/callback?code=abc&origin=/anotherRoute")), Route.login(.githubCallback(code: "abc", origin: "/anotherRoute")))
    }
}
