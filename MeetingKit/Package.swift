// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MeetingKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MeetingKit", targets: ["MeetingKit"]),
        .library(name: "MeetingUI", targets: ["MeetingUI"]),
    ],
    dependencies: [
        // Core ML pyannote segmentation + WeSpeaker embeddings for offline diarization.
        // Apache-2.0; builds with Command Line Tools alone; its floor is macOS 14 like ours.
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.17.4"),
    ],
    targets: [
        .target(name: "MeetingKit", dependencies: [.product(name: "FluidAudio", package: "FluidAudio")]),
        .target(name: "MeetingUI", dependencies: ["MeetingKit"]),
        .testTarget(name: "MeetingKitTests", dependencies: ["MeetingKit"]),
    ]
)
