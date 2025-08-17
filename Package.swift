// swift-tools-version: 5.9
// Package.swift for MLX dependency documentation
// This file documents the MLX dependency that should be added to the Xcode project

import PackageDescription

let package = Package(
    name: "ManyLLM",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // MLX Swift package for Apple Silicon optimization
        .package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.12.0")
    ],
    targets: [
        .target(
            name: "ManyLLM",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXRandom", package: "mlx-swift")
            ]
        )
    ]
)