// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LocalTranscriber",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LocalTranscriber", targets: ["LocalTranscriber"])],
    targets: [
        .target(name: "TranscriberCore"),
        .executableTarget(name: "LocalTranscriber", dependencies: ["TranscriberCore"]),
        .testTarget(name: "TranscriberCoreTests", dependencies: ["TranscriberCore"]),
        .testTarget(name: "LocalTranscriberTests", dependencies: ["LocalTranscriber"])
    ],
    swiftLanguageModes: [.v5]
)
