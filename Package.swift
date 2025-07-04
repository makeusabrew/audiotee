// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "audiotee",
    platforms: [
        .macOS("14.2")
    ],
    targets: [
        .executableTarget(
            name: "audiotee",
            swiftSettings: [
                .define("ENABLE_TCC_SPI")
            ])
        // linkerSettings: [
        //     .unsafeFlags([
        //         "-Xlinker", "-sectcreate",
        //         "-Xlinker", "__TEXT",
        //         "-Xlinker", "__info_plist",
        //         "-Xlinker", "Resources/Info.plist",
        //     ])
    ]
)
