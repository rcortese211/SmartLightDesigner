// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HueBase",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "HueBase",
            path: "Sources/HueBase"
        )
    ]
)
