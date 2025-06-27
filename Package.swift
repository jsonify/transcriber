// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "transcriber",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "transcriber",
            targets: ["TranscriberCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "TranscriberCLI",
            dependencies: [
                "TranscriberCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "TranscriberCore",
            dependencies: []
        ),
        .testTarget(
            name: "TranscriberTests",
            dependencies: ["TranscriberCore", "TranscriberCLI"]
        ),
    ]
)
