// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "QuickCV",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.16.0")
    ],
    targets: [
        .executableTarget(
            name: "QuickCV",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Sources/QuickCV"
        )
    ]
)
