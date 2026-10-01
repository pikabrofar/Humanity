// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AIKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AIKit", targets: ["AIKit"]),
        .library(name: "AIKitUI", targets: ["AIKitUI"]),
    ],
    targets: [
        .target(name: "AIKit"),
        .target(name: "AIKitUI", dependencies: ["AIKit"]),
        .testTarget(name: "AIKitTests", dependencies: ["AIKit"]),
    ]
)
