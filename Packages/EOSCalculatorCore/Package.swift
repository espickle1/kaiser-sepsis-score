// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EOSCalculatorCore",
    platforms: [
        .iOS(.v17),
        // macOS is included only so `swift test` runs on a Mac without a simulator.
        .macOS(.v14),
    ],
    products: [
        .library(name: "EOSCalculatorCore", targets: ["EOSCalculatorCore"]),
    ],
    targets: [
        .target(name: "EOSCalculatorCore"),
        .testTarget(
            name: "EOSCalculatorCoreTests",
            dependencies: ["EOSCalculatorCore"],
            resources: [.copy("Resources/test_vectors.json")]
        ),
    ]
)
