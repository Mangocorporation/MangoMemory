// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MangoMemory",
    platforms: [.macOS(.v26)],
    targets: [
        // Rules and data logic with no SwiftUI, so tests run without the app.
        .target(name: "MangoMemoryKit"),
        .executableTarget(
            name: "MangoMemory",
            dependencies: ["MangoMemoryKit"],
            // App code runs on the main thread unless you say otherwise.
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        // The root helper that runs purge (SMAppService.daemon). build.sh embeds it.
        .executableTarget(name: "MangoMemoryHelper", dependencies: ["MangoMemoryKit"]),
        .testTarget(name: "MangoMemoryKitTests", dependencies: ["MangoMemoryKit"]),
    ]
)
