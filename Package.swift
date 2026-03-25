// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Glimpse",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "Glimpse", targets: ["Glimpse"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/facebook/meta-wearables-dat-ios",
            from: "0.1.0"
        )
    ],
    targets: [
        .target(
            name: "Glimpse",
            dependencies: [
                .product(name: "WearablesKit", package: "meta-wearables-dat-ios")
            ],
            path: "Glimpse"
        )
    ]
)
