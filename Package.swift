// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Timekeep",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Timekeep",
            path: "Sources/Timekeep"
        )
    ]
)
