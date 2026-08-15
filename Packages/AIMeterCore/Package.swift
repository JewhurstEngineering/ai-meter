// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIMeterCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "AIMeterCore", targets: ["AIMeterCore"]),
    ],
    targets: [
        .target(
            name: "AIMeterCore",
            path: "Sources/AIMeterCore",
            linkerSettings: [
                .linkedLibrary("sqlite3", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "AIMeterCoreTests",
            dependencies: ["AIMeterCore"],
            path: "Tests/AIMeterCoreTests",
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
