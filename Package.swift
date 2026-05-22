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
        .executable(name: "HerminalApp", targets: ["HerminalApp"]),
        .library(name: "HerminalCore", targets: ["HerminalCore"]),
        .library(name: "HerminalDB", targets: ["HerminalDB"]),
        .library(name: "HerminalAgent", targets: ["HerminalAgent"])
    ],
    dependencies: [
        // SQLite wrapper (SQLite.swift by stephencelis)
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
    ],
    targets: [
        // libghostty C ABI — prebuilt xcframework from the vendored Ghostty v1.3.1.
        // Rebuild with: Scripts/bootstrap.sh
        .binaryTarget(
            name: "GhosttyKit",
            path: "Vendor/libghostty/macos/GhosttyKit.xcframework"
        ),
        .target(
            name: "HerminalCore",
            dependencies: ["GhosttyKit"],
            path: "Sources/HerminalCore",
            linkerSettings: [
                // Frameworks + C++ runtime pulled in by the static libghostty-fat.a
                // (it bundles glslang / spirv-cross, which are C++).
                .linkedLibrary("c++"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("CoreText"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit"),
                .linkedFramework("QuartzCore"),
                .linkedFramework("Carbon"),
                .linkedFramework("CoreServices"),
                .linkedFramework("IOSurface"),
                .linkedFramework("UniformTypeIdentifiers")
            ]
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
        .executableTarget(
            name: "HerminalApp",
            dependencies: ["HerminalCore", "HerminalDB", "HerminalAgent", "GhosttyKit"],
            path: "Sources/HerminalApp"
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
        ),
        .testTarget(
            name: "HerminalAppTests",
            dependencies: ["HerminalApp"],
            path: "Tests/HerminalAppTests"
        )
    ],
    swiftLanguageVersions: [.v6]
)
