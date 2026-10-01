// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Ojos",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GazeKit", targets: ["GazeKit"]),
        .library(name: "OjosUI", targets: ["OjosUI"]),
        .executable(name: "Ojos", targets: ["Ojos"]),
    ],
    targets: [
        .target(name: "GazeKit"),
        .target(name: "OjosUI", dependencies: ["GazeKit"]),
        .executableTarget(name: "Ojos", dependencies: ["OjosUI"]),
        .testTarget(
            name: "GazeKitTests",
            dependencies: ["GazeKit", "OjosUI"]
        ),
    ]
)
