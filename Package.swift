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
        .executable(
            name: "TranscriberApp",
            targets: ["TranscriberApp"]
        ),
        .library(
            name: "TranscriberCore",
            targets: ["TranscriberCore"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .executableTarget(
            name: "TranscriberCLI",
            dependencies: [
                "TranscriberCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "TranscriberApp",
            dependencies: ["TranscriberCore"],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .define("APPKIT_PREVIEW_AVAILABLE", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "TranscriberCore",
            dependencies: ["Yams"]
        ),
        .testTarget(
            name: "TranscriberTests",
            dependencies: ["TranscriberCore", "TranscriberCLI"]
        )
    ]
)
