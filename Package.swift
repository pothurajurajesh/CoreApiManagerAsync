// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CoreApiManagerAsync",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "CoreApiManagerAsync",
            targets: ["CoreApiManagerAsync"]
        )
    ],
    targets: [
        .target(
            name: "CoreApiManagerAsync",
            dependencies: []
        ),
        .testTarget(
            name: "CoreApiManagerAsyncTests",
            dependencies: ["CoreApiManagerAsync"]
        )
    ]
)
