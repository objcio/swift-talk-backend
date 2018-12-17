// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swifttalk-server",
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
		]),
        .target(
            name: "swifttalk-server",
        	dependencies: [
                "SwiftTalkServerLib"
        	]
        ),
        .testTarget(
            name: "SwiftTalkTests",
        	dependencies: ["SwiftTalkServerLib"]
        )
    ]
)
