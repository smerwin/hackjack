// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Hackjack",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .library(name: "HackjackCore", targets: ["HackjackCore"]),
    ],
    targets: [
        .target(
            name: "HackjackCore"
        ),
        .executableTarget(
            name: "HackjackCLI",
            dependencies: ["HackjackCore"]
        ),
        .testTarget(
            name: "HackjackCoreTests",
            dependencies: ["HackjackCore"]
        ),
    ]
)
