// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonCoding",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "LNTCSVCoding",
            targets: ["LNTCSVCoding"]),
        .library(
            name: "LNTBinaryCoding",
            targets: ["LNTBinaryCoding"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "LNTCSVCoding",
            dependencies: ["LNTSharedCoding"]),
        .target(
            name: "LNTBinaryCoding",
            dependencies: ["LNTSharedCoding"]),
        .target(name: "LNTSharedCoding"),

        .testTarget(
            name: "LNTCSVCodingTests",
            dependencies: ["LNTCSVCoding"]),
        .testTarget(
            name: "LNTBinaryCodingTests",
            dependencies: ["LNTBinaryCoding"]),
        .testTarget(
            name: "LNTSharedCodingTests",
            dependencies: ["LNTSharedCoding"]),
    ]
)
