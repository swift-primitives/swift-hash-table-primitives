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
        )
    ],
    dependencies: [
        .package(path: "../swift-index-primitives"),
        .package(path: "../swift-hash-primitives"),
    ],
    targets: [
        .target(
            name: "Hash Table Primitives",
            dependencies: [
                .product(name: "Index Primitives", package: "swift-index-primitives"),
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
            ]
        ),
        .testTarget(
            name: "Hash Table Primitives Tests",
            dependencies: [
                "Hash Table Primitives",
                .product(name: "Hash Primitives", package: "swift-hash-primitives"),
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
