// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AWDL-JIT",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .executable(name: "awdl-jit-ls", targets: ["LaunchServicesTool"]),
    ],
    targets: [
        .executableTarget(
            name: "LaunchServicesTool",
            path: "Sources/LaunchServicesTool"
        ),
    ]
)
