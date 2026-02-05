// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HaxEdit",
    targets: [
        .executableTarget(
            name: "HaxEdit",
            path: "Sources/HaxEdit"
        ),
        .testTarget(
            name: "HaxEditTests",
            dependencies: ["HaxEdit"],
            path: "Tests/HaxEditTests"
        ),
    ]
)
