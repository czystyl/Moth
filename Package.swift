// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Moth",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Moth",
            path: "Sources/Moth",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
