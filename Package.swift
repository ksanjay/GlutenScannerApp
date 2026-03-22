// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GlutenFreeCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "GlutenFreeCore",
            targets: ["GlutenFreeCore"]
        )
    ],
    targets: [
        .target(
            name: "GlutenFreeCore"
        ),
        .testTarget(
            name: "GlutenFreeCoreTests",
            dependencies: ["GlutenFreeCore"]
        )
    ]
)
