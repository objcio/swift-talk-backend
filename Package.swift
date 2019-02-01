// swift-tools-version:4.2

import PackageDescription

let package = Package(
    name: "swifttalk-server",
    products: [
        .executable(name: "swifttalk-server", targets: ["swifttalk-server"]),
        .library(name: "SwiftTalkServerLib", targets: ["SwiftTalkServerLib"]),
        .library(name: "Routing", targets: ["Routing"]),
        .library(name: "Base", targets: ["Base"]),
        .library(name: "Promise", targets: ["Promise"]),
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "NIOWrapper", targets: ["NIOWrapper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "1.5.0"),
		.package(url: "https://github.com/vapor-community/postgresql.git", .exact("2.1.2")),
        .package(url: "https://github.com/objcio/commonmark-swift", .branch("memory")),
        .package(url:"https://github.com/PerfectlySoft/Perfect-XML.git", .exact("3.1.3")),
		.package(url: "https://github.com/IBM-Swift/BlueCryptor", .exact("1.0.20")),
        .package(url: "https://github.com/jpsim/SourceKitten", from: "0.22.0"),
    ],
    targets: [
        .target(
            name: "Base",
            dependencies: [
                "Cryptor",
            ],
            path: "Sources/Base"
        ),
        .target(
            name: "Promise",
            dependencies: [
            ],
            path: "Sources/Promise"
        ),
        .target(
            name: "Networking",
            dependencies: [
            ],
            path: "Sources/Networking"
        ),
        .target(
            name: "NIOWrapper",
            dependencies: [
                "Base",
                "Promise",
                "NIO",
                "NIOHTTP1",
                "NIOFoundationCompat"
            ],
            path: "Sources/NIOWrapper"
        ),
        .target(
            name: "Routing",
            dependencies: [
                "Base",
            ],
            path: "Sources/Routing"
        ),
        .target(
            name: "SwiftTalkServerLib",
            dependencies: [
                "Networking",
                "Promise",
                "Base",
                "Routing",
                "NIOWrapper",
				"PostgreSQL",
                "CommonMark",
                "PerfectXML",
				"Cryptor",
				"SourceKittenFramework",
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
		.target(
			name: "highlight-html",
			dependencies: [
                "SourceKittenFramework",
                "CommonMark"
			],
			path: "Sources/highlight-html"
		),
        .testTarget(
            name: "SwiftTalkTests",
        	dependencies: ["SwiftTalkServerLib"],
			path: "Tests"
        )
    ]
)
