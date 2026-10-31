// swift-tools-version:6.0
import PackageDescription

// Lua's deepest C recursion (LUAI_MAXCCALLS levels) peaks at 95 KB of wasm stack; see docs/decisions/010-cart-runtime.md.
let wasmStackBytes = 1 << 20

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
                // Half of Lua's default: 200 nested C calls overflowed WebKit's native stack once it was cut to iOS's 1 MB; see decision 010.
                .define("LUAI_MAXCCALLS", to: "100"),
                .define("_WASI_EMULATED_SIGNAL", .when(platforms: [.wasi])),
                .define("_WASI_EMULATED_PROCESS_CLOCKS", .when(platforms: [.wasi])),
                .unsafeFlags(["-mllvm", "-wasm-enable-sjlj"], .when(platforms: [.wasi])),
            ],
            linkerSettings: [
                .linkedLibrary("setjmp", .when(platforms: [.wasi])),
            ]
        ),
        .target(name: "Runtime", dependencies: ["CLua", "Console"]),
        .executableTarget(
            name: "App",
            dependencies: [
                "Console",
                "Runtime",
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
            ],
            linkerSettings: [
                // wasm-ld rejects a --global-base below the stack size under --stack-first, and the Swift driver otherwise passes 4096.
                .unsafeFlags([
                    "-Xlinker", "-z", "-Xlinker", "stack-size=\(wasmStackBytes)",
                    "-Xlinker", "--stack-first", "-Xlinker", "--global-base=\(wasmStackBytes)",
                ], .when(platforms: [.wasi])),
            ]
        ),
        .testTarget(name: "ConsoleTests", dependencies: ["Console"], exclude: ["Golden"]),
        .testTarget(name: "RuntimeTests", dependencies: ["Runtime", "Console"]),
    ]
)
