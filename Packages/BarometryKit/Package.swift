// swift-tools-version: 6.2

// SPDX-FileCopyrightText: 2026 Nick Wolff <nick@wolff.tech>
// SPDX-License-Identifier: GPL-3.0-only
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
