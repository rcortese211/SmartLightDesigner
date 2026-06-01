// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartLightPi",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
    ],
    targets: [
        .executableTarget(
            name: "SmartLightPi",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ],
            path: "Sources/SmartLightPi",
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        )
    ]
)
