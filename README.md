# FES

Frank Entertainment System: a fantasy console for the browser on iPad. Swift compiled to WebAssembly runs the console; a small JavaScript layer boots it. See `docs/SPEC.md`.

## Toolchain

You need Swift 6.4.1, the Swift Wasm SDK for it, and Node 22 or later.

On Linux (or on macOS once swiftly is installed), `scripts/setup.sh` installs Swift and the SDK, then the Node packages and Playwright's WebKit:

```
bash scripts/setup.sh
```

Or by hand:

1. Install [swiftly](https://www.swift.org/install/), then `swiftly install 6.4.1 --use`.
2. Install the Wasm SDK. The URL and checksum are in `scripts/setup.sh`:
   ```
   swift sdk install <WASM_SDK_URL> --checksum <WASM_SDK_CHECKSUM>
   ```
   `swift sdk list` should now show `swift-6.4.1-RELEASE_wasm`.
3. Install Node 22, then `npm ci`.

## Build

```
npm run build
```

This compiles the Swift package to `App.wasm` and bundles the page into `web/dist/`. The first build takes about 10 minutes, because JavaScriptKit's build plugin compiles swift-syntax. Later builds take seconds.

## Serve

```
npm run serve
```

Open http://localhost:8000/ in Safari. You should see a blue screen, scaled up by a whole number to fit the window, and two lines of Lua output at the top-left: `6 * 7 = 42` and `pcall caught: fail:1: boom`.

To try it on the iPad, use the Network URL that esbuild prints (the iPad must be on the same Wi-Fi).
