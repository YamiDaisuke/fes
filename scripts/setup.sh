#!/usr/bin/env bash
set -euo pipefail

SWIFT_VERSION=6.4.1
WASM_SDK_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/wasm-sdk/swift-${SWIFT_VERSION}-RELEASE/swift-${SWIFT_VERSION}-RELEASE_wasm.artifactbundle.tar.gz"
WASM_SDK_CHECKSUM=783e6128d174d9f975b4eda68be02a5960681b723ef372e6876a7c2543a365d8

if ! command -v swiftly >/dev/null; then
  cd "$(mktemp -d)"
  curl -fsSLO "https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz"
  tar zxf "swiftly-$(uname -m).tar.gz"
  ./swiftly init --quiet-shell-followup --assume-yes --skip-install
  cd - >/dev/null
fi
. "${SWIFTLY_HOME_DIR:-$HOME/.local/share/swiftly}/env.sh"

swiftly install "$SWIFT_VERSION" --use --assume-yes
swift sdk list | grep -q "swift-${SWIFT_VERSION}-RELEASE_wasm" \
  || swift sdk install "$WASM_SDK_URL" --checksum "$WASM_SDK_CHECKSUM"

if [ -f package.json ]; then
  npm ci
  npx playwright install --with-deps webkit
fi
