// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "swifttalk-server",
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git",
                 from: "1.5.0")
    ],
    targets: [
        .target(
            name: "swifttalk-server",
            dependencies: [
                "NIO",
                "NIOHTTP1",
		]),
    ]
)
