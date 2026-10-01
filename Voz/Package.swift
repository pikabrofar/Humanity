// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Voz",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VozKit", targets: ["VozKit"]),
        .library(name: "VozUI", targets: ["VozUI"]),
        .executable(name: "Voz", targets: ["Voz"]),
    ],
    targets: [
        .target(name: "VozKit"),
        .executableTarget(name: "Voz", dependencies: ["VozUI"]),
        .target(
            name: "VozUI",
            dependencies: ["VozKit"],
            // FoundationModels ships only with macOS 26. Weak-linking it lets the
            // same binary launch on macOS 14 and 15, where cleanup falls back to regexes.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "FoundationModels"])]
        ),
        .testTarget(name: "VozKitTests", dependencies: ["VozKit"]),
    ]
)
