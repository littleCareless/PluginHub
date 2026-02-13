// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PluginHub",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PluginHub",
            targets: ["PluginHub"]
        ),
        .library(
            name: "PluginHubCore",
            targets: ["PluginHub"]
        )
    ],
    targets: [
        .executableTarget(
            name: "PluginHub",
            dependencies: [],
            path: "Sources/App",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PluginHubTests",
            dependencies: ["PluginHub"],
            path: "Tests"
        )
    ]
)
