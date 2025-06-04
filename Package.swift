// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "ImmersalKit",
  platforms: [
    .visionOS(.v2)
  ],
  products: [
    .library(
      name: "ImmersalKit",
      targets: ["ImmersalKit"])
  ],
  dependencies: [],
  targets: [
    .systemLibrary(
      name: "PosePlugin",
      pkgConfig: nil,
      providers: nil
    ),
    .target(
      name: "ImmersalKit",
      dependencies: [
        .target(name: "PosePlugin")
      ],
      swiftSettings: [
        .swiftLanguageMode(.v5)
      ]
    ),
    .testTarget(
      name: "ImmersalKitTests",
      dependencies: ["ImmersalKit"]
    ),
  ]
)
