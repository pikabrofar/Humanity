// swift-tools-version: 5.10
import PackageDescription

/// Sentidos: one app hosting every Sentidos module, sharing one camera.
let package = Package(
    name: "Sentidos",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../Ojos"),
        .package(path: "../Manos"),
        .package(path: "../Bocas"),
        .package(path: "../AIKit"),
    ],
    targets: [
        .executableTarget(
            name: "Sentidos",
            dependencies: [
                .product(name: "OjosUI", package: "Ojos"),
                .product(name: "GazeKit", package: "Ojos"),
                .product(name: "ManosUI", package: "Manos"),
                .product(name: "BocasUI", package: "Bocas"),
                .product(name: "AIKitUI", package: "AIKit"),
            ]
        ),
    ]
)
