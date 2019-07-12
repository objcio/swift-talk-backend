// swift-tools-version:5.0

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
        .library(name: "HTML", targets: ["HTML"]),
        .library(name: "Database", targets: ["Database"]),
        .library(name: "WebServer", targets: ["WebServer"]),
        .library(name: "Incremental", targets: ["Incremental"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/objcio/commonmark-swift", .branch("master")),
        .package(url: "https://github.com/objcio/LibPQ", .branch("master")),
		.package(url: "https://github.com/IBM-Swift/BlueCryptor", .exact("1.0.30")),
        .package(url: "https://github.com/jpsim/SourceKitten", from: "0.22.0"),
		.package(url: "https://github.com/ianpartridge/swift-backtrace.git", from: "1.0.2"),
    ],
    targets: [
        .target(
            name: "Incremental",
            dependencies: [
            ],
            path: "Sources/Incremental"
        ),
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
                "NIOFoundationCompat",
            ],
            path: "Sources/NIOWrapper"
        ),
        .target(
            name: "HTML",
            dependencies: [ "Base" ],
            path: "Sources/HTML"
        ),
        .target(
            name: "Routing",
            dependencies: [
                "Base",
            ],
            path: "Sources/Routing"
        ),
        .target(
            name: "Database",
            dependencies: [
                "LibPQ",
                "Base",
            ],
            path: "Sources/Database"
        ),
        .target(
            name: "WebServer",
            dependencies: [
                "Base",
                "HTML",
                "NIOWrapper",
                "Promise",
                "Database",
            ],
            path: "Sources/WebServer"
        ),
        .target(
            name: "SwiftTalkServerLib",
            dependencies: [
                "Incremental",
                "Networking",
                "Promise",
                "Base",
                "Routing",
                "HTML",
                "NIOWrapper",
                "Database",
                "WebServer",
                "CommonMark",
				"Cryptor",
				"SourceKittenFramework",
			],
			path: "Sources/SwiftTalkServerLib"
		),
        .target(
            name: "swifttalk-server",
        	dependencies: [
                "SwiftTalkServerLib",
				"Backtrace",
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
    ],
    swiftLanguageVersions: [.v5]
)
