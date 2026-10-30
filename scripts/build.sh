#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# A separate scratch path keeps native and wasm builds from invalidating each other (docs/decisions/002-wasm-build-and-packaging.md).
swift package --scratch-path .build/wasm --swift-sdk swift-6.4.1-RELEASE_wasm js -c release --output .build/js

rm -rf web/dist
mkdir -p web/dist
npx esbuild web/boot.js --bundle --format=esm --outfile=web/dist/boot.js
cp web/index.html .build/js/App.wasm web/dist/
