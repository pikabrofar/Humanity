// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Manos",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HandKit", targets: ["HandKit"]),
        .library(name: "ManosUI", targets: ["ManosUI"]),
        .executable(name: "Manos", targets: ["Manos"]),
    ],
    dependencies: [
        // Camera capture (and later gaze + pinch) come from ojoS's GazeKit.
        .package(path: "../Ojos"),
    ],
    targets: [
        .target(name: "HandKit"),
        .target(name: "ManosUI", dependencies: ["HandKit", .product(name: "GazeKit", package: "Ojos")]),
        .executableTarget(name: "Manos", dependencies: ["ManosUI"]),
        .testTarget(name: "HandKitTests", dependencies: ["HandKit"]),
    ]
)
