// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swiftui-range-slider",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(name: "RangeSlider", targets: ["RangeSlider"])
    ],
    targets: [
        .target(
            name: "RangeSlider",
            resources: [
                .process("Shaders")
            ]
        )
    ]
)
