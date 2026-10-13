// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Breeze",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Breeze", targets: ["Breeze"]),
        .library(name: "BreezeKit", targets: ["BreezeKit"]),
    ],
    targets: [
        // UI-free domain models, TCL cloud client and credential storage.
        .target(name: "BreezeKit"),
        // SwiftUI app: desktop window, menu bar extra and settings.
        .executableTarget(name: "Breeze", dependencies: ["BreezeKit"]),
        .testTarget(name: "BreezeKitTests", dependencies: ["BreezeKit"]),
    ],
    swiftLanguageModes: [.v6]
)
