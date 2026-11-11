# AIE Pocket / Apple Watch

Build Evan's conference schedule: choose talks in a Flutter iPhone companion, then swipe title, presenter, location, and time cards on Apple Watch. Preserve authoritative source content and explicit conference timezone. Flutter does not target watchOS; the watch UI is SwiftUI.

`lib/` owns the companion and watch preview. `assets/` holds the sourced offline catalogue. `ios/` owns the Flutter host and phone bridge. `watch/` owns the watch app and complication. Keep the selected schedule local, and send complete versioned snapshots; an empty list clears the watch. Do not label a queued transfer as delivered.

Run `scripts/check.sh` for Dart analysis, behavior tests, and the web build. Xcode builds and paired-device WatchConnectivity checks require macOS; record them as unverified until actually run. Browser-test companion selection, persistence, filters and watch preview at phone and desktop widths. Read `docs/BUILD.md` for Apple build steps and `docs/DATA.md` for schedule provenance.
