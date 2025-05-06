// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "combine-async-await",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "CombineAsyncAwait",
            targets: ["CombineAsyncAwait"]),
    ],
    dependencies: [
        // No external dependencies
    ],
    targets: [
        .target(
            name: "CombineAsyncAwait",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Combine")
            ]),
        .testTarget(
            name: "CombineAsyncAwaitTests",
            dependencies: ["CombineAsyncAwait"],
            linkerSettings: [
                .linkedFramework("Combine")
            ]),
    ]
)
