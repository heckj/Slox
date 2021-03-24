// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift
// required to build this package.

import PackageDescription

let package = Package(
    name: "LOX",
    platforms: [.macOS(.v10_15), .iOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces,
        // and make them visible to other packages.
        .library(
            name: "Slox",
            targets: ["Slox"]
        ),
        .executable(name: "slox-cli", targets: ["cli"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-argument-parser",
            .upToNextMinor(from: "0.3.0")
        ),
    ],
    targets: [
        .target(
            name: "cli",
            dependencies: [
                .target(name: "Slox"),
                .product(name: "ArgumentParser",
                         package: "swift-argument-parser"),
            ]
        ),
        // Targets are the basic building blocks of a package.
        // A target can define a module or a test suite.
        // Targets can depend on other targets in this package,
        // and on products in packages this package depends on.
        .target(
            name: "Slox",
            dependencies: []
        ),
        .testTarget(
            name: "SloxTests",
            dependencies: ["Slox"]
        ),
    ]
)
