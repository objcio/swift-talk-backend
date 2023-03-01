// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "swifttalk-server",
    platforms: [
        .macOS(.v12)
    ],
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
        .package(url: "https://github.com/apple/swift-nio.git", .exact("2.40.0")),
        .package(url: "https://github.com/chriseidhof/commonmark-swift", .branch("embed-c")),
        .package(url: "https://github.com/objcio/LibPQ", .branch("master")),
        .package(url: "https://github.com/objcio/tiny-networking", from: "0.2.0"),
        .package(url: "https://github.com/objcio/swift-talk-shared", from: "0.2.0"),
        .package(url: "https://github.com/objcio/md5", .exact("0.1.0")),
        .package(url: "https://github.com/jpsim/SourceKitten", .exact("0.29.0")), // todo 0.29 introduces a breaking change.
        .package(url: "https://github.com/ianpartridge/swift-backtrace.git", from: "1.0.2"),
        .package(url: "https://github.com/chriseidhof/backend-experiments", .branch("main")),
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
                .product(name: "TinyNetworking", package: "tiny-networking"),

            ],
            path: "Sources/Networking"
        ),
        .target(
            name: "NIOWrapper",
            dependencies: [
                "Base",
                "Promise",
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
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
//                "EndpointBuilder",
                "Incremental",
                .product(name: "TinyNetworking", package: "tiny-networking"),
                "Networking",
                "Promise",
                "Base",
                "Routing",
                "HTML",
                "NIOWrapper",
                "Database",
                "WebServer",
                .product(name: "CommonMark", package: "commonmark-swift"),
                .product(name: "Model", package: "swift-talk-shared"),
                .product(name: "ViewHelpers", package: "swift-talk-shared"),
				"md5",
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
			],
			path: "Sources/SwiftTalkServerLib"
		),
        .target(
            name: "swifttalk-server",
        	dependencies: [
                "SwiftTalkServerLib",
                .product(name: "Backtrace", package: "swift-backtrace")
        	],
			path: "Sources/swifttalk-server"
        ),
		.target(
			name: "highlight-html",
			dependencies: [
                .product(name: "SourceKittenFramework", package: "SourceKitten"),
                .product(name: "CommonMark", package: "commonmark-swift"),
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
