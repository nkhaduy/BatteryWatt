// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BatteryWatt",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "BatteryWatt", targets: ["BatteryWatt"])
    ],
    targets: [
        .executableTarget(
            name: "BatteryWatt",
            path: "Sources"
        )
    ]
)
