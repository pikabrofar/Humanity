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
    dependencies: [
        // Optional bring-your-own-key cloud models (Groq, Gemini, OpenAI, Anthropic…).
        .package(path: "../AIKit"),
    ],
    targets: [
        .target(name: "MurmurKit"),
        .executableTarget(name: "Murmur", dependencies: ["MurmurUI", .product(name: "AIKitUI", package: "AIKit")]),
        .target(
            name: "MurmurUI",
            dependencies: ["MurmurKit", .product(name: "AIKit", package: "AIKit")],
            // FoundationModels ships only with macOS 26. Weak-linking it lets the
            // same binary launch on macOS 14 and 15, where cleanup falls back to regexes.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "FoundationModels"])]
        ),
        .testTarget(name: "MurmurKitTests", dependencies: ["MurmurKit"]),
    ]
)
