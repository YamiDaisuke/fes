# 002 Wasm build and packaging
Status: accepted (2026-10-25, T01)
Context: Swift must reach the browser as wasm plus a JS loader, built the same way on any machine and served as static files.
Decision: JavaScriptKit's PackageToJS plugin builds App with the swift-6.4.1-RELEASE_wasm SDK in its own scratch path (.build/wasm) into .build/js. esbuild bundles web/boot.js with that loader and its WASI shim into web/dist/, next to App.wasm. esbuild's --servedir serves it locally. The shim is `@bjorn3/browser_wasi_shim@0.3.0`, the version JavaScriptKit 0.61.0 pins; the owner approved it as a dependency on issue #1.
Alternatives: a hand-written loader and WASI stubs (new code JavaScriptKit already provides); --use-cdn for the shim (breaks offline); the embedded Wasm SDK (smaller, but restricts Swift; revisit for the audio module); sharing .build with native builds (every switch costs a 6–8 minute rebuild).
