// swift-tools-version: 5.10
import PackageDescription

/// License activation shared by every Humanity app: one Gumroad key unlocks them all.
let package = Package(
    name: "LicenseKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "LicenseKit", targets: ["LicenseKit"])],
    targets: [
        .target(name: "LicenseKit"),
        .testTarget(name: "LicenseKitTests", dependencies: ["LicenseKit"]),
    ]
)
