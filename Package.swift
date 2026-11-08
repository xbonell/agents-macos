// swift-tools-version:5.9
import PackageDescription

let package = Package(
  name: "Agents",
  platforms: [.macOS(.v14)],
  targets: [
    .executableTarget(
      name: "Agents",
      path: "Sources/Agents",
      resources: [.copy("Resources")]
    ),
  ]
)
