// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ManOS",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HandKit", targets: ["HandKit"]),
        .executable(name: "ManOS", targets: ["ManOS"]),
    ],
    dependencies: [
        // Camera capture (and later gaze + pinch) come from VisionGaze's GazeKit.
        .package(path: "../VisionGaze"),
    ],
    targets: [
        .target(name: "HandKit"),
        .executableTarget(
            name: "ManOS",
            dependencies: ["HandKit", .product(name: "GazeKit", package: "VisionGaze")]
        ),
        .testTarget(name: "HandKitTests", dependencies: ["HandKit"]),
    ]
)
