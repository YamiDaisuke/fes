// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FES",
    dependencies: [
        .package(url: "https://github.com/swiftwasm/JavaScriptKit", exact: "0.61.0"),
    ],
    targets: [
        .target(name: "Console"),
        .target(
            name: "CLua",
            cSettings: [
                .define("_WASI_EMULATED_SIGNAL", .when(platforms: [.wasi])),
                .define("_WASI_EMULATED_PROCESS_CLOCKS", .when(platforms: [.wasi])),
                .unsafeFlags(["-mllvm", "-wasm-enable-sjlj"], .when(platforms: [.wasi])),
            ],
            linkerSettings: [
                .linkedLibrary("setjmp", .when(platforms: [.wasi])),
            ]
        ),
        .target(name: "Runtime", dependencies: ["CLua"]),
        .executableTarget(
            name: "App",
            dependencies: [
                "Console",
                "Runtime",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ]
        ),
        .testTarget(name: "ConsoleTests", dependencies: ["Console"], exclude: ["Golden"]),
        .testTarget(name: "RuntimeTests", dependencies: ["Runtime"]),
    ]
)
