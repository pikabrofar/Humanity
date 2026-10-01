// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "VisionGaze",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GazeKit", targets: ["GazeKit"]),
        .library(name: "VisionGazeUI", targets: ["VisionGazeUI"]),
        .executable(name: "VisionGaze", targets: ["VisionGaze"]),
    ],
    targets: [
        .target(name: "GazeKit"),
        .target(name: "VisionGazeUI", dependencies: ["GazeKit"]),
        .executableTarget(name: "VisionGaze", dependencies: ["VisionGazeUI"]),
        .testTarget(
            name: "GazeKitTests",
            dependencies: ["GazeKit"]
        ),
    ]
)
