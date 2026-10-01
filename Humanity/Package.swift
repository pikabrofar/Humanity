// swift-tools-version: 5.10
import PackageDescription

/// Humanity: one app hosting every Humanity module, sharing one camera.
let package = Package(
    name: "Humanity",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../OculOS"),
        .package(path: "../ManOS"),
        .package(path: "../Murmur"),
    ],
    targets: [
        .executableTarget(
            name: "Humanity",
            dependencies: [
                .product(name: "OculOSUI", package: "OculOS"),
                .product(name: "GazeKit", package: "OculOS"),
                .product(name: "ManOSUI", package: "ManOS"),
                .product(name: "MurmurUI", package: "Murmur"),
            ]
        ),
    ]
)
