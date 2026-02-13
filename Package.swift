// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AIPluginManager",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AIPluginManager",
            targets: ["AIPluginManager"]
        ),
        .library(
            name: "AIPluginManagerCore",
            targets: ["AIPluginManager"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AIPluginManager",
            dependencies: [],
            path: "Sources/App",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AIPluginManagerTests",
            dependencies: ["AIPluginManager"],
            path: "Tests"
        )
    ]
)
