// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swifttalk-server",
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git",
                 from: "1.5.0"),
		.package(url: "https://github.com/vapor-community/postgresql.git", .exact("2.1.2")),
        .package(url: "https://github.com/chriseidhof/commonmark-swift", .branch("master")),
    ],
    targets: [
        .target(
            name: "swifttalk-server",
            dependencies: [
                "NIO",
                "NIOHTTP1",
				"PostgreSQL",
                "CommonMark",
		]),
    ]
)
