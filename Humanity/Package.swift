// swift-tools-version: 5.10
import PackageDescription

/// Humanity: one app hosting every OculOS module, sharing one camera.
let package = Package(
    name: "Humanity",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../VisionGaze"),
        .package(path: "../ManOS"),
    ],
    targets: [
        .executableTarget(
            name: "Humanity",
            dependencies: [
                .product(name: "VisionGazeUI", package: "VisionGaze"),
                .product(name: "GazeKit", package: "VisionGaze"),
                .product(name: "ManOSUI", package: "ManOS"),
            ]
        ),
    ]
)
