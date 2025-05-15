// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FableKit",
    platforms: [.visionOS(.v2), .iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "FableKit",
            targets: ["FableKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms.git", .upToNextMajor(from: "1.0.2")),
        .package(url: "https://github.com/apple/swift-log", from: "1.6.2"),
        .package(url: "https://github.com/wlisac/swift-log-slack", from: "0.1.0"),
        .package(url: "https://github.com/chrisaljoudi/swift-log-oslog", from: "0.2.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "FableKit",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "LoggingSlack", package: "swift-log-slack"),
                .product(name: "LoggingOSLog", package: "swift-log-oslog")
            ]
        ),
        .testTarget(
            name: "FableKitTests",
            dependencies: ["FableKit"]
        ),
    ]
)
