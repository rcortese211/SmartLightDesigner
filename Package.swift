// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartLightDesigner",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SmartLightDesigner",
            path: "Sources/SmartLightDesigner"
        )
    ]
)
