// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Timekeep",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/damuellen/xlsxwriter.swift", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "Timekeep",
            dependencies: [
                .product(name: "xlsxwriter", package: "xlsxwriter.swift")
            ],
            path: "Sources/Timekeep"
        )
    ]
)
