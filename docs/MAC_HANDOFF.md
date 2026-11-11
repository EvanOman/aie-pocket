# Continue development on a Mac

AIE Pocket already includes a Flutter iPhone companion, native SwiftUI watch cards, WatchConnectivity synchronization, offline watch cache, background reception, and circular/rectangular complications. The Xcode project includes **Runner**, **AIEWatch**, and **AIEComplication** with their dependencies and embedding configured.

Read [BUILD.md](BUILD.md), [VERIFICATION.md](VERIFICATION.md), and [DATA.md](DATA.md) before changing the implementation. Inspect the current branch and working-tree state, preserve existing changes, and use a dedicated worktree for new branch work.

## Current evidence

Flutter analysis and 21 tests passed after the day-navigation update. Apple simulator builds and a native Ultra swipe test passed. Simulator checks covered delivery, offline persistence, clear-to-empty, add-back recovery, complication rendering/opening, and observed background selection refresh. One reconnection attempt required reopening the phone; a later retest delivered without reopening it.

Signed builds installed and launched on a physical iPhone and 49 mm Apple Watch Ultra. The watch received and rendered a 38-talk schedule. Physical swipe, offline, clearing, and complication checks remain unverified. Complication current/next transitions still need runtime observation. Full details and screenshot provenance are in [VERIFICATION.md](VERIFICATION.md).

## Resume

Use Flutter **3.38.10** / Dart **3.10.9**, Xcode with the required iOS/watchOS SDKs, CocoaPods, and Ruby `xcodeproj`. Follow the clean setup and simulator commands in [BUILD.md](BUILD.md). Runtime simulator builds require ad-hoc signing for App Group registration; unsigned builds establish compilation only.

```sh
flutter --version
xcodebuild -version
xcodebuild -showsdks
pod --version
ruby -e 'require "xcodeproj"; puts Xcodeproj::VERSION'
flutter pub get
./scripts/check.sh
./scripts/check_apple_on_mac.sh
```

Configure your own bundle identifiers and signing team before physical installation. Inspect any existing device selection before tests that clear or replace it. Run the remaining [physical experience checks](BUILD.md#verify-the-experience), and update the verification record with device models, OS/tool versions, commands, and observed results. Keep device identifiers, signing-team values, credentials, and local network details out of committed evidence.

Preserve the 112-session snapshot, 37 optional recommendations, stable session IDs, source attribution, and explicit Pacific timestamps. Selections from the source website and browser preview do not automatically transfer to the phone. Full snapshots, including an empty list, replace the watch selection; “queued” must never imply confirmed delivery.
