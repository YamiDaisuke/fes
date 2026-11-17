#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# A separate scratch path keeps native and wasm builds from invalidating each other (docs/decisions/002-wasm-build-and-packaging.md).
swift package --scratch-path .build/wasm --swift-sdk swift-6.4.1-RELEASE_wasm js -c release --output .build/js

rm -rf web/dist
mkdir -p web/dist
npx esbuild web/boot.js --bundle --format=esm --outfile=web/dist/boot.js
cp web/index.html web/look.html web/style.css .build/js/App.wasm web/dist/
cp web/manifest.webmanifest web/dist/
cp -R web/icons web/fonts web/ui web/dist/
version=$(cd web/dist && find . -type f | sort | xargs sha256sum | sha256sum | cut -c1-16)
files=$(cd web/dist && find . -type f ! -path ./index.html | sort | sed 's|^\./\(.*\)|"\1"|' | paste -sd, -)
sed -e "s/BUILD_VERSION/$version/" -e "s|PRECACHE_FILES|[\"./\",$files]|" web/sw.js > web/dist/sw.js
