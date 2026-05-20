// swift-tools-version:6.0
// herminal — AI-native macOS terminal for Vietnamese developers
// SPM manifest for core libraries. The .app target lives in App/ (Xcode project).

import PackageDescription

let package = Package(
    name: "herminal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "HerminalCore", targets: ["HerminalCore"]),
        .library(name: "HerminalDB", targets: ["HerminalDB"]),
        .library(name: "HerminalAgent", targets: ["HerminalAgent"])
    ],
    dependencies: [
        // SQLite wrapper (SQLite.swift by stephencelis)
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
        // libghostty will be added as system library (xcframework) once vendored
    ],
    targets: [
        .target(
            name: "HerminalCore",
            path: "Sources/HerminalCore"
        ),
        .target(
            name: "HerminalDB",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/HerminalDB"
        ),
        .target(
            name: "HerminalAgent",
            dependencies: ["HerminalCore"],
            path: "Sources/HerminalAgent"
        ),
        .testTarget(
            name: "HerminalCoreTests",
            dependencies: ["HerminalCore"],
            path: "Tests/HerminalCoreTests"
        ),
        .testTarget(
            name: "HerminalDBTests",
            dependencies: ["HerminalDB"],
            path: "Tests/HerminalDBTests"
        ),
        .testTarget(
            name: "HerminalAgentTests",
            dependencies: ["HerminalAgent"],
            path: "Tests/HerminalAgentTests"
        )
    ],
    swiftLanguageVersions: [.v6]
)
