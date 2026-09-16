// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SwiftTalkStatic",
    platforms: [.macOS(.v12)],
    products: [.executable(name: "swift-talk-static", targets: ["swift-talk-static"])],
    dependencies: [
        // Use the same Markdown parser as the existing site, without its server dependencies.
        .package(url: "https://github.com/chriseidhof/commonmark-swift", revision: "df72c50897a0494ccd606d5105818475915b2778"),
        .package(url: "https://github.com/jpsim/SourceKitten", exact: "0.31.1")
    ],
    targets: [
        .target(name: "SwiftTalkStatic", dependencies: [
            .product(name: "CommonMark", package: "commonmark-swift"),
            .product(name: "SourceKittenFramework", package: "SourceKitten")
        ]),
        .executableTarget(name: "swift-talk-static", dependencies: ["SwiftTalkStatic"]),
        .testTarget(name: "SwiftTalkStaticTests", dependencies: ["SwiftTalkStatic"])
    ]
)
