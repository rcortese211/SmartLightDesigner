// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartLight",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SmartLight",
            path: "Sources/HueBase"
        )
    ]
)
