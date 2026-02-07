// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-hash-table-primitives",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26)
    ],
    products: [
        .library(
            name: "Hash Table Primitives",
            targets: ["Hash Table Primitives"]
        ),
        .library(
            name: "Hash Table Primitives Core",
            targets: ["Hash Table Primitives Core"]
        ),
        .library(
            name: "Hash Table Primitives Test Support",
            targets: ["Hash Table Primitives Test Support"]
        ),
    ],
    dependencies: [
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-hash-primitives"),
        .package(path: "../swift-property-primitives"),
        .package(path: "../swift-ordinal-primitives"),
        .package(path: "../swift-cardinal-primitives"),
        .package(path: "../swift-cyclic-index-primitives"),
    ],
    targets: [
        // Layer 1: Core type definitions (no constraint poisoning)
        .target(
            name: "Hash Table Primitives Core",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
                .product(name: "Ordinal Primitives", package: "swift-ordinal-primitives"),
                .product(name: "Cardinal Primitives", package: "swift-cardinal-primitives"),
                .product(name: "Cyclic Index Primitives", package: "swift-cyclic-index-primitives"),
            ]
        ),
        // Layer 2: Full API + re-export
        .target(
            name: "Hash Table Primitives",
            dependencies: [
                "Hash Table Primitives Core",
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ]
        ),
        // Test Support: test helpers and re-exports
        .target(
            name: "Hash Table Primitives Test Support",
            dependencies: [
                "Hash Table Primitives",
                .product(name: "Index Primitives Test Support", package: "swift-index-primitives"),
            ],
            path: "Tests/Support"
        ),
        .testTarget(
            name: "Hash Table Primitives Tests",
            dependencies: [
                "Hash Table Primitives",
                "Hash Table Primitives Test Support",
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
