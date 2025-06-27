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
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
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
            dependencies: [
                .product(name: "Yams", package: "Yams"),
            ]
        ),
        .testTarget(
            name: "TranscriberTests",
            dependencies: ["TranscriberCore", "TranscriberCLI"]
        ),
    ]
)
