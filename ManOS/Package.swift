// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ManOS",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HandKit", targets: ["HandKit"]),
        .library(name: "ManOSUI", targets: ["ManOSUI"]),
        .executable(name: "ManOS", targets: ["ManOS"]),
    ],
    dependencies: [
        // Camera capture (and later gaze + pinch) come from OculOS's GazeKit.
        .package(path: "../OculOS"),
    ],
    targets: [
        .target(name: "HandKit"),
        .target(name: "ManOSUI", dependencies: ["HandKit", .product(name: "GazeKit", package: "OculOS")]),
        .executableTarget(name: "ManOS", dependencies: ["ManOSUI"]),
        .testTarget(name: "HandKitTests", dependencies: ["HandKit"]),
    ]
)
