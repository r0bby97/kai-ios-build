// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FadenCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "FadenCore", targets: ["FadenCore"])],
    targets: [
        .target(name: "FadenCore", resources: [.process("Resources")]),
        .testTarget(name: "FadenCoreTests", dependencies: ["FadenCore"])
    ],
    swiftLanguageModes: [.v5]
)
