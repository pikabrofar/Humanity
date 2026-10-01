// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MurmurKit", targets: ["MurmurKit"]),
        .library(name: "MurmurUI", targets: ["MurmurUI"]),
        .executable(name: "Murmur", targets: ["Murmur"]),
    ],
    targets: [
        .target(name: "MurmurKit"),
        .executableTarget(name: "Murmur", dependencies: ["MurmurUI"]),
        .target(
            name: "MurmurUI",
            dependencies: ["MurmurKit"],
            // FoundationModels ships only with macOS 26. Weak-linking it lets the
            // same binary launch on macOS 14 and 15, where cleanup falls back to regexes.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "FoundationModels"])]
        ),
        .testTarget(name: "MurmurKitTests", dependencies: ["MurmurKit"]),
    ]
)
