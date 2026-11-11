#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
DART_BIN="${DART_BIN:-dart}"
"$FLUTTER_BIN" pub get --enforce-lockfile
"$DART_BIN" format --output=none --set-exit-if-changed lib test
"$FLUTTER_BIN" analyze --no-pub --fatal-infos --fatal-warnings
"$FLUTTER_BIN" test --no-pub --coverage --reporter expanded
"$FLUTTER_BIN" build web --no-pub --release --base-href "${WEB_BASE_HREF:-/}" --no-web-resources-cdn
if command -v ruby >/dev/null && ruby -e 'require "xcodeproj"' >/dev/null 2>&1; then
  ruby scripts/configure_apple.rb --check
elif [[ "${REQUIRE_APPLE_PROJECT_CHECK:-0}" == 1 ]]; then
  printf '%s\n' 'ERROR: required Apple project check cannot load xcodeproj. Run bundle install, then bundle exec ./scripts/check.sh.' >&2
  exit 1
else
  printf '%s\n' 'SKIP: static Apple project check needs bundle install and bundle exec ./scripts/check.sh.'
fi
