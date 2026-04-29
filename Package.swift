// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "holodeck",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "holodeck", targets: ["holodeck"]),
        .library(name: "HolodeckCore", targets: ["HolodeckCore"]),
        .library(name: "HolodeckServices", targets: ["HolodeckServices"]),
        .library(name: "HolodeckTUI", targets: ["HolodeckTUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(name: "HolodeckCore"),
        .target(name: "HolodeckServices", dependencies: ["HolodeckCore"]),
        .target(name: "HolodeckTUI", dependencies: ["HolodeckServices"]),
        .executableTarget(
            name: "holodeck",
            dependencies: [
                "HolodeckCore",
                "HolodeckServices",
                "HolodeckTUI",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "HolodeckCoreTests",
            dependencies: ["HolodeckCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "HolodeckServicesTests",
            dependencies: ["HolodeckServices"]
        ),
        .testTarget(
            name: "HolodeckTUITests",
            dependencies: ["HolodeckTUI"]
        )
    ]
)
