#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v swiftc >/dev/null || { echo 'Swift compiler required. Run this check on macOS or in an official Swift Linux container.' >&2; exit 1; }
check_dir="$(mktemp -d)"
trap 'rm -rf "$check_dir"' EXIT
swiftc watch/Shared/ScheduleSnapshot.swift watch/Tests/SnapshotChecks.swift -o "$check_dir/snapshot-checks"
"$check_dir/snapshot-checks" assets/schedule.json
swiftc -frontend -parse watch/Shared/ScheduleSnapshot.swift watch/App/*.swift \
  watch/Complication/*.swift ios/Runner/AppDelegate.swift ios/Runner/ScheduleBridge.swift
echo 'PASS: Swift source syntax. Apple framework type checking and runtime behavior still require Xcode.'
