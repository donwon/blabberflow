// swift-tools-version: 5.8
import PackageDescription
let package = Package(name: "WhisperFlow", platforms: [.macOS(.v13)], products: [.executable(name: "WhisperFlow", targets: ["WhisperFlow"])], targets: [.target(name: "FlowCore"), .executableTarget(name: "WhisperFlow", dependencies: ["FlowCore"]), .testTarget(name: "FlowCoreTests", dependencies: ["FlowCore"]), .testTarget(name: "WhisperFlowTests", dependencies: ["WhisperFlow"])])
