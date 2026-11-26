// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SkyrimTogether",
    platforms: [.macOS(.v14)],
    targets: [
        // What the launch scripts print and where they are: no UI, so it can be tested
        .target(name: "LauncherCore"),
        .executableTarget(name: "SkyrimTogether", dependencies: ["LauncherCore"]),
        .testTarget(name: "LauncherCoreTests", dependencies: ["LauncherCore"]),
    ]
)
