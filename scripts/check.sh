#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test
"$FLUTTER_BIN" build web --release --base-href "${WEB_BASE_HREF:-/}" --no-web-resources-cdn
if command -v ruby >/dev/null && ruby -e 'require "xcodeproj"' >/dev/null 2>&1; then
  ruby scripts/configure_apple.rb --check
fi
