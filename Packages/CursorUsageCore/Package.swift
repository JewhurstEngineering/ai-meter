// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CursorUsageCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "CursorUsageCore", targets: ["CursorUsageCore"]),
    ],
    targets: [
        .target(
            name: "CursorUsageCore",
            path: "Sources/CursorUsageCore",
            linkerSettings: [
                .linkedLibrary("sqlite3", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "CursorUsageCoreTests",
            dependencies: ["CursorUsageCore"],
            path: "Tests/CursorUsageCoreTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
