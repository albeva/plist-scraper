// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "plist-scraper",
    dependencies: [
        .package(url: "https://github.com/xcodeswift/xcproj.git", .upToNextMajor(from: "1.8.0")),
        .package(url: "https://github.com/yaslab/CSV.swift.git", .upToNextMajor(from: "2.1.0")),
        .package(url: "https://github.com/kylef/Commander.git", .upToNextMajor(from: "0.8.0"))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "plist-scraper",
            dependencies: ["xcproj", "CSV", "Commander"]
        ),
    ]
)
