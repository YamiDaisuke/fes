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

Open http://localhost:8000/ in Safari. You should see the demo cart, scaled up by a whole number to fit the window, with the touch controller over it: a sprite in a walled room of bricks. The D-pad or the arrow keys walk it, the view follows, and A (or Z) changes its colors.

To try it on the iPad, use the Network URL that esbuild prints (the iPad must be on the same Wi-Fi).

## Test

```
swift test
npm run build && npm run test:browser
```

`swift test` runs the Swift core tests natively. Rendering tests compare frames with the PNGs in each test target's `Golden/` folder (`Tests/ConsoleTests/Golden/`, `Tests/RuntimeTests/Golden/`); a mismatch writes `<name>.actual.png` beside the golden so you can compare the two. To re-record goldens after an intended change, run `FES_RECORD_GOLDENS=1 swift test` (it fails on purpose), check the new PNGs and commit them.

`test:browser` serves `web/dist/` and runs a Playwright smoke test in WebKit with an iPad profile.

CI runs both on every PR and on `main`, then publishes to GitHub Pages: `main` at the site root, each PR at `/pr/<number>/`, linked from a comment on the PR. See `docs/decisions/003-ci-and-pr-previews.md`.
