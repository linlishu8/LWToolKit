// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LWToolKit",
    platforms: [
        .iOS(.v14)
    ],
    products: [
        .library(name: "LWCore", targets: ["LWCore"]),
        .library(name: "LWMedia", targets: ["LWMedia"]),
        .library(name: "LWUI", targets: ["LWUI"]),
        .library(name: "LWAnalytics", targets: ["LWAnalytics"]),
    ],
    targets: [
        .target(name: "LWCore", path: "Sources/LWCore"),
        .target(name: "LWMedia", dependencies: ["LWCore"], path: "Sources/LWMedia"),
        .target(name: "LWUI", dependencies: ["LWCore"], path: "Sources/LWUI"),
        .target(name: "LWAnalytics", dependencies: ["LWCore"], path: "Sources/LWAnalytics"),
        .testTarget(name: "LWCoreTests", dependencies: ["LWCore"], path: "Tests/LWCoreTests"),
    ]
)