// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BatteryWatt",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "BatteryWatt", targets: ["BatteryWatt"])
    ],
    targets: [
        .target(
            name: "BatteryWattCore",
            path: "Sources/Core"
        ),
        .executableTarget(
            name: "BatteryWatt",
            dependencies: ["BatteryWattCore"],
            path: "Sources/App",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "BatteryWattCoreTests",
            dependencies: ["BatteryWattCore"],
            path: "Tests/BatteryWattCoreTests"
        )
    ]
)
