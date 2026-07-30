// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TestStepHUD",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "TestStepHUD",
            targets: ["TestStepHUD"]
        ),
        .library(
            name: "TestStepHUDTestSupport",
            targets: ["TestStepHUDTestSupport"]
        )
    ],
    targets: [
        .target(
            name: "TestStepHUDProtocol"
        ),
        .target(
            name: "TestStepHUD",
            dependencies: ["TestStepHUDProtocol"]
        ),
        .target(
            name: "TestStepHUDTestSupport",
            dependencies: ["TestStepHUDProtocol"]
        ),
        .testTarget(
            name: "TestStepHUDProtocolTests",
            dependencies: [
                "TestStepHUDProtocol",
                "TestStepHUDTestSupport"
            ]
        )
    ]
)
