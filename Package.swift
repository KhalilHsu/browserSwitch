// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BrowserRouter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BrowserRouter", targets: ["BrowserRouter"])
    ],
    targets: [
        .executableTarget(
            name: "BrowserRouter",
            path: "Sources/BrowserRouter"
        )
    ]
)
