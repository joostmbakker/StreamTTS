// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StreamTTSDemo",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(name: "StreamTTS", path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "StreamTTSDemo",
            dependencies: [
                .product(name: "StreamTTSCore", package: "StreamTTS"),
                .product(name: "StreamTTSElevenLabs", package: "StreamTTS"),
                .product(name: "StreamTTSGoogleCloud", package: "StreamTTS"),
            ]
        ),
    ]
)
