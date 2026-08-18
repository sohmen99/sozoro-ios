// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SozoroCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "SozoroCore", targets: ["SozoroCore"])],
    targets: [
        .target(name: "SozoroCore", resources: [.process("Resources")]),
        .testTarget(name: "SozoroCoreTests", dependencies: ["SozoroCore"],
                    resources: [.process("golden.json")])
    ]
)
