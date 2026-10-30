// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FES",
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", exact: "0.61.0"),
    ],
    targets: [
        .target(name: "Console"),
        .executableTarget(
            name: "App",
            dependencies: [
                "Console",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ]
        ),
    ]
)
