// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Muxi",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        .library(
            name: "Muxi",
            targets: ["Muxi"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Muxi",
            dependencies: []),
        .testTarget(
            name: "MuxiTests",
            dependencies: ["Muxi"]),
    ]
)
