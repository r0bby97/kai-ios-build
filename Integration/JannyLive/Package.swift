// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "JannyLiveProbe", platforms: [.macOS(.v14)], dependencies: [.package(name: "FadenCore", path: "../..")], targets: [.executableTarget(name: "JannyLiveProbe", dependencies: [.product(name: "FadenCore", package: "FadenCore")], path: "Sources")], swiftLanguageModes: [.v5])
