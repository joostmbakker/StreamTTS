// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StreamTTS",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "StreamTTSCore", targets: ["StreamTTSCore"]),
        .library(name: "StreamTTSGoogleCloud", targets: ["StreamTTSGoogleCloud"]),
        .library(name: "StreamTTSElevenLabs", targets: ["StreamTTSElevenLabs"]),
    ],
    dependencies: [
        .package(url: "https://github.com/grpc/grpc-swift.git", exact: "1.23.0"), // pinned to v1.x
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0")
    ],
    targets: [
        .target(name: "StreamTTSCore"),
        .target(
            name: "StreamTTSGoogleCloud",
            dependencies: [
                "StreamTTSCore",
                .product(name: "GRPC", package: "grpc-swift"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ]
        ),
        .target(
            name: "StreamTTSElevenLabs",
            dependencies: [
                "StreamTTSCore",
            ]
        ),
        .testTarget(name: "StreamTTSCoreTests", dependencies: ["StreamTTSCore"]),
        .testTarget(name: "StreamTTSGoogleCloudTests", dependencies: ["StreamTTSGoogleCloud"]),
        .testTarget(name: "StreamTTSElevenLabsTests", dependencies: ["StreamTTSElevenLabs"]),
    ]
)
