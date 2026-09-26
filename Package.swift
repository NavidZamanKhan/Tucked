// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tucked",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Tucked",
            targets: ["Tucked"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Tucked",
            path: "Sources/Tucked"
        ),
        .testTarget(
            name: "TuckedTests",
            dependencies: ["Tucked"],
            path: "Tests/TuckedTests"
        ),
    ]
)
