// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "Realias",
  platforms: [.macOS(.v13)],
  targets: [
    .executableTarget(name: "Realias", path: "Sources/Realias")
  ]
)
