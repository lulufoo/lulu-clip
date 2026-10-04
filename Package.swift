// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "lulu-clip",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "lulu-clip", targets: ["lulu-clip"]),
        .library(name: "LuluClipCore", targets: ["LuluClipCore"]),
    ],
    targets: [
        .target(name: "LuluClipCore"),
        .executableTarget(
            name: "lulu-clip",
            dependencies: ["LuluClipCore"]
        ),
        .testTarget(
            name: "LuluClipCoreTests",
            dependencies: ["LuluClipCore"]
        ),
    ]
)
