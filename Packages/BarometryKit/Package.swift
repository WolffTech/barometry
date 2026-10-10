// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BarometryKit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "BarometryKit", targets: ["BarometryKit"]),
    ],
    targets: [
        .target(name: "BarometryKit"),
        .testTarget(name: "BarometryKitTests", dependencies: ["BarometryKit"]),
    ]
)
