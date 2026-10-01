// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OculOS",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GazeKit", targets: ["GazeKit"]),
        .library(name: "OculOSUI", targets: ["OculOSUI"]),
        .executable(name: "OculOS", targets: ["OculOS"]),
    ],
    targets: [
        .target(name: "GazeKit"),
        .target(name: "OculOSUI", dependencies: ["GazeKit"]),
        .executableTarget(name: "OculOS", dependencies: ["OculOSUI"]),
        .testTarget(
            name: "GazeKitTests",
            dependencies: ["GazeKit", "OculOSUI"]
        ),
    ]
)
