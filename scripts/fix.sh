#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"
"$FLUTTER_BIN" pub get --enforce-lockfile
"$DART_BIN" fix --apply
"$DART_BIN" format lib test
