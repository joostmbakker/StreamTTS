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
        .package(url: "https://github.com/grpc/grpc-swift-2.git", from: "2.3.0"),
        .package(url: "https://github.com/grpc/grpc-swift-nio-transport.git", from: "2.3.0"),
        .package(url: "https://github.com/grpc/grpc-swift-protobuf.git", from: "2.2.0"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
    ],
    targets: [
        .target(name: "StreamTTSCore"),
        .target(
            name: "StreamTTSGoogleCloud",
            dependencies: [
                "StreamTTSCore",
                .product(name: "GRPCCore", package: "grpc-swift-2"),
                .product(name: "GRPCNIOTransportHTTP2", package: "grpc-swift-nio-transport"),
                .product(name: "GRPCProtobuf", package: "grpc-swift-protobuf"),
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
