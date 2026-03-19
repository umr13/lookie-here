// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LookieHere",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "LookieHereCore", targets: ["LookieHereCore"]),
        .executable(name: "lookie", targets: ["lookie"]),
        .executable(name: "LookieHereApp", targets: ["LookieHereApp"]),
    ],
    targets: [
        .target(
            name: "LookieHereCore",
            path: "Sources/LookieHereCore"
        ),
        .executableTarget(
            name: "lookie",
            dependencies: ["LookieHereCore"],
            path: "Sources/lookie"
        ),
        .executableTarget(
            name: "LookieHereApp",
            dependencies: ["LookieHereCore"],
            path: "Sources/LookieHereApp"
        ),
        .testTarget(
            name: "LookieHereCoreTests",
            dependencies: ["LookieHereCore"],
            path: "Tests/LookieHereCoreTests"
        ),
    ]
)
