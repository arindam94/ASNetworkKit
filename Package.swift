// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ASNetworkKit",
    platforms: [
        .iOS(.v13), .macOS(.v12), .tvOS(.v13), .watchOS(.v6)
    ],
    products: [
        .library(
            name: "ASNetworkKit",
            targets: ["ASNetworkKit"]
        ),
    ],
    targets: [
        .target(
            name: "ASNetworkKit",
            dependencies: [],
            path: "Sources/ASNetworkKit"
        ),
        .testTarget(
            name: "ASNetworkKitTests",
            dependencies: ["ASNetworkKit"],
            path: "Tests/ASNetworkKitTests"
        ),
    ]
)
