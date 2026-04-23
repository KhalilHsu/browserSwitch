// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BrowserRouter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BrowserRouterCore", targets: ["BrowserRouterCore"]),
        .executable(name: "BrowserRouter", targets: ["BrowserRouter"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BrowserRouterCore",
            path: "Sources/BrowserRouterCore"
        ),
        .executableTarget(
            name: "BrowserRouter",
            dependencies: ["BrowserRouterCore"],
            path: "Sources/BrowserRouter"
        ),
        .testTarget(
            name: "BrowserRouterCoreTests",
            dependencies: ["BrowserRouterCore"],
            path: "Tests/BrowserRouterCoreTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-L", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        ),
        .testTarget(
            name: "BrowserRouterTests",
            dependencies: ["BrowserRouter"],
            path: "Tests/BrowserRouterTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-L", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ]
)
