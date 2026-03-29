// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "nook",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Core",
            targets: ["Core"]
        ),
        .executable(
            name: "nook",
            targets: ["AppShell"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/simibac/ConfettiSwiftUI.git", from: "1.1.0"),
    ],
    targets: [
        .target(
            name: "Core"
        ),
        .executableTarget(
            name: "AppShell",
            dependencies: ["Core", "ConfettiSwiftUI"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"]
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell", "Core"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
