// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Bocas",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BocasKit", targets: ["BocasKit"]),
        .library(name: "BocasUI", targets: ["BocasUI"]),
        .executable(name: "Bocas", targets: ["Bocas"]),
    ],
    dependencies: [
        // Optional bring-your-own-key cloud models (Groq, Gemini, OpenAI, Anthropic…).
        .package(path: "../AIKit"),
        // Meeting capture, speaker diarization and voice profiles.
        .package(path: "../MeetingKit"),
    ],
    targets: [
        .target(name: "BocasKit"),
        .executableTarget(name: "Bocas", dependencies: ["BocasUI", .product(name: "AIKitUI", package: "AIKit")]),
        .target(
            name: "BocasUI",
            dependencies: ["BocasKit", .product(name: "AIKit", package: "AIKit"),
                           .product(name: "MeetingKit", package: "MeetingKit"),
                           .product(name: "MeetingUI", package: "MeetingKit")],
            // FoundationModels ships only with macOS 26. Weak-linking it lets the
            // same binary launch on macOS 14 and 15, where cleanup falls back to regexes.
            linkerSettings: [.unsafeFlags(["-Xlinker", "-weak_framework", "-Xlinker", "FoundationModels"])]
        ),
        .testTarget(name: "BocasKitTests", dependencies: ["BocasKit"]),
    ]
)
