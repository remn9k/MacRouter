// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacRouter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MacRouter",
            targets: ["MacRouter"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MacRouter",
            dependencies: [],
            path: "Sources/MacRouter"
        )
    ]
)
