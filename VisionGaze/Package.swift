// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VisionGaze",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GazeKit", targets: ["GazeKit"]),
        .executable(name: "VisionGaze", targets: ["VisionGaze"]),
    ],
    targets: [
        .target(name: "GazeKit"),
        .executableTarget(
            name: "VisionGaze",
            dependencies: ["GazeKit"]
        ),
        .testTarget(
            name: "GazeKitTests",
            dependencies: ["GazeKit"]
        ),
    ]
)
