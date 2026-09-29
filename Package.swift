// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NetTrace",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "NetTrace", targets: ["NetTrace"]),
    ],
    targets: [
        .target(name: "NetTrace"),
        .testTarget(name: "NetTraceTests", dependencies: ["NetTrace"]),
    ]
)
