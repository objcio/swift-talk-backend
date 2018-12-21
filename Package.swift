// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swifttalk-server",
    products: [
        .executable(name: "swifttalk-server", targets: ["swifttalk-server"]),
        .library(name: "SwiftTalkServerLib", targets: ["SwiftTalkServerLib"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git",
                 from: "1.5.0"),
		.package(url: "https://github.com/vapor-community/postgresql.git", .exact("2.1.2")),
        .package(url: "https://github.com/objcio/commonmark-swift", .branch("master")),
        .package(url:"https://github.com/PerfectlySoft/Perfect-XML.git", .exact("3.1.3")),
		.package(url: "https://github.com/IBM-Swift/BlueCryptor", .exact("1.0.20")),
    ],
    targets: [
        .target(
            name: "SwiftTalkServerLib",
            dependencies: [
                "NIO",
                "NIOHTTP1",
                "NIOFoundationCompat",
				"PostgreSQL",
                "CommonMark",
                "PerfectXML",
				"Cryptor",
			],
			path: "Sources/SwiftTalkServerLib"
		),
        .target(
            name: "swifttalk-server",
        	dependencies: [
                "SwiftTalkServerLib"
        	],
			path: "Sources/swifttalk-server"
        ),
        .testTarget(
            name: "SwiftTalkTests",
        	dependencies: ["SwiftTalkServerLib"],
			path: "Tests"
        )
    ]
)
