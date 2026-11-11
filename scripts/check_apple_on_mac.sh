#!/usr/bin/env bash
# Compile Apple targets without signing; run on a Mac with Xcode SDKs installed.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'This check requires macOS and Xcode.' >&2; exit 1; }
for tool in flutter xcodebuild pod ruby; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done
ruby -e 'require "xcodeproj"' || { echo 'Install xcodeproj: gem install xcodeproj -v 1.27.0 --user-install' >&2; exit 1; }
# A fresh clone has no generated plugin registrant; pub get creates it before
# the project checker validates every source reference.
flutter pub get
ruby scripts/configure_apple.rb --check
./scripts/check_swift.sh
flutter build ios --config-only --simulator
pod install --project-directory=ios
xcodebuild -project ios/Runner.xcodeproj -scheme AIEWatch \
  -configuration Debug -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
printf '%s\n' 'Apple compilation passed. Next: run on paired simulators/devices using docs/BUILD.md.'
