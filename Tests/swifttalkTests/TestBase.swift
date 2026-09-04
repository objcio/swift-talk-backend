//
//  TestBase.swift
//  Backtrace
//
//  Created by Chris Eidhof on 05.08.19.
//

import Foundation
import Base
import Database
import WebServer
import XCTest
@testable import SwiftTalkServerLib

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

    func testSubscribeOnlyShowsMonthlyArchiveAccess() throws {
        pushTestEnv()
        let requestEnvironment = STRequestEnvironment(
            route: .signup(.subscribe(planName: nil)),
            hashedAssetName: { $0 },
            buildSession: { nil },
            connection: noConnection,
            resourcePaths: resourcePaths
        )
        let html = renderSubscribe(monthly: plans[0]).htmlDocument(input: requestEnvironment)

        XCTAssertTrue(html.contains("monthly"))
        XCTAssertFalse(html.contains("yearly"))
        XCTAssertTrue(html.contains("Access to the full archive"))
        XCTAssertFalse(html.contains("A new episode every week"))
        XCTAssertTrue(html.contains("Help us keep the full archive available"))
        XCTAssertFalse(html.contains("keep producing new episodes"))
        let signIn = try XCTUnwrap(html.range(of: "Sign in with Github"))
        let firstBannerLine = try XCTUnwrap(html.range(of: "We&#39;re not recording new episodes anymore."))
        let secondBannerLine = try XCTUnwrap(html.range(of: "Subscribe to get access to the full archive."))
        XCTAssertLessThan(signIn.lowerBound, firstBannerLine.lowerBound)
        XCTAssertLessThan(firstBannerLine.lowerBound, secondBannerLine.lowerBound)
        XCTAssertTrue(html.contains("bgcolor-invalid text-center"))
    }

    func testCachedPlansDecodeWithRecurlyKeys() throws {
        let json = #"[{"plan_interval_unit":"months","unit_amount_in_cents":{"USD":1500},"plan_interval_length":1,"plan_code":"monthly_plan","name":"Monthly Plan"}]"#
        let decoded = try JSONDecoder().decode([Plan].self, from: Data(json.utf8))

        XCTAssertEqual(decoded.first?.plan_code, "monthly_plan")
        XCTAssertEqual(decoded.first?.unit_amount_in_cents.usdCents, 1500)
    }

    func testHomeShowsArchiveMode() {
        pushTestEnv()
        let requestEnvironment = STRequestEnvironment(
            route: .home,
            hashedAssetName: { $0 },
            buildSession: { nil },
            connection: noConnection,
            resourcePaths: resourcePaths
        )
        let html = renderHome(episodes: []).htmlDocument(input: requestEnvironment)

        XCTAssertTrue(html.contains("label smallcaps color-blue-darkest bgcolor-orange"))
        XCTAssertTrue(html.contains("Archive Mode"))
        XCTAssertTrue(html.contains("A video series on Swift programming."))
        XCTAssertFalse(html.contains("weekly video series"))
    }
}
