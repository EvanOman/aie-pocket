# Build and install AIE Pocket

The companion is Flutter. The watch app and its watch-face complication are native SwiftUI, connected with WatchConnectivity. The Xcode project contains all three targets; no manual target creation is needed. See [VERIFICATION.md](VERIFICATION.md) for recorded builds, simulator observations, physical-device results, and remaining checks.

## Mac setup

Use Flutter **3.38.10** with Dart **3.10.9**, Xcode with iOS and watchOS SDKs, CocoaPods, and Ruby with the `xcodeproj` gem. The recorded Mac setup used CocoaPods **1.17.0**, Ruby **3.3.12**, and xcodeproj **1.28.1**. The app targets iOS 13+ and watchOS 10+.

Keep Flutter pinned for reproducibility. During development, Flutter 3.47.5 attempted to raise the iOS deployment target to 15 and add Swift Package Manager integration. This project retains Flutter 3.38.10's CocoaPods setup.

Install the tools and any required simulator runtimes before continuing. Put Flutter and CocoaPods on `PATH`. If several Xcode versions are installed, select the appropriate application for the current shell with `DEVELOPER_DIR`; use an Xcode version compatible with the devices or runtimes you intend to test.

```bash
# Adjust this application path if using a differently named Xcode install.
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
flutter --version
xcodebuild -version
xcodebuild -showsdks
pod --version
ruby -e 'require "xcodeproj"; puts Xcodeproj::VERSION'
```

Run from the repository root:

```bash
flutter pub get
flutter build ios --config-only --simulator
pod install --project-directory=ios
./scripts/check.sh
```

`flutter pub get` generates the excluded plugin registrant needed by the static Xcode project check. No signing account is needed for simulator builds. The watch targets use only system frameworks.

## Compile Apple targets

Run the complete Mac preflight:

```bash
./scripts/check_apple_on_mac.sh
```

It generates Flutter configuration, installs the locked CocoaPods dependencies, checks the shared Swift model and Xcode graph, and builds the watch and companion for simulators without signing. It exits immediately on Linux. Compilation does not establish schedule delivery or App Group runtime behavior.

For individual checks:

```bash
./scripts/check_swift.sh
ruby scripts/configure_apple.rb --check

xcodebuild -project ios/Runner.xcodeproj -scheme AIEWatch \
  -configuration Debug -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Use `-destination` rather than forcing one SDK across the iOS/watchOS target graph. The Swift model check can also run with a Swift compiler on Linux; source parsing there does not typecheck Apple frameworks.

## Run paired simulators

Use a paired iPhone and **49 mm Apple Watch Ultra** simulator to reproduce the principal verification setup. Choose compatible installed runtimes in Xcode's Devices and Simulators window. `xcrun simctl list devices available` lists local identifiers. Set `PHONE_UDID` and `WATCH_UDID` to your simulator identifiers; the examples below use shell placeholders that must be replaced.

**Runtime testing requires ad-hoc signing.** The unsigned compile-check build did not register its App Group container. Build with `CODE_SIGN_IDENTITY=-` and omit `CODE_SIGNING_ALLOWED=NO` so the watch app and complication can share their cache.

```bash
export PHONE_UDID='<your iPhone simulator identifier>'
export WATCH_UDID='<your Watch simulator identifier>'

# Pair only if these simulators are not already paired.
xcrun simctl pair "$WATCH_UDID" "$PHONE_UDID"
# Boot each device in Simulator, then wait until both are ready.
xcrun simctl bootstatus "$PHONE_UDID" -b
xcrun simctl bootstatus "$WATCH_UDID" -b

xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination "platform=iOS Simulator,id=$PHONE_UDID" \
  -derivedDataPath build/apple-simulator CODE_SIGN_IDENTITY=- build
xcodebuild -project ios/Runner.xcodeproj -scheme AIEWatch \
  -configuration Debug -destination "platform=watchOS Simulator,id=$WATCH_UDID" \
  -derivedDataPath build/apple-simulator CODE_SIGN_IDENTITY=- build

xcrun simctl install "$PHONE_UDID" build/apple-simulator/Build/Products/Debug-iphonesimulator/Runner.app
xcrun simctl install "$WATCH_UDID" build/apple-simulator/Build/Products/Debug-watchsimulator/AIEWatch.app
xcrun simctl launch "$PHONE_UDID" com.example.aiepocket
xcrun simctl launch "$WATCH_UDID" com.example.aiepocket.watch
```

Adjust the launch identifiers if you configured different bundle IDs. Simulator results do not substitute for physical paired-device checks.

## Repeat the native watch swipe test

The shared **AIEWatchUITests** scheme runs `watch/UITests/TalkNavigationTests.swift` against the native app on an existing Ultra simulator. Prepare its fixture through the actual iPhone companion: choose only **More Checks, Less Noise: Layered Security for AI-Assisted Development** (`1357875`) and **Notion Software Factory Debate** (`notion`), then observe both arrive on the watch. This replaces the test simulator's selection; use a dedicated test pair if you need to retain another schedule.

The test does not seed a cache or simulate WatchConnectivity receipt. It checks **1/2 → swipe left → 2/2 → swipe right → 1/2**, including the visible title and the opposite position becoming non-hittable. The app opens its current/next talk, so the test normalizes either starting page to `1/2` before the round trip. Disable parallel testing to use the prepared simulator instead of an empty clone.

With `WATCH_UDID` set above, run from the repository root. The result path must not already exist; choose a fresh name on repeats.

```bash
xcodebuild -project ios/Runner.xcodeproj -scheme AIEWatchUITests \
  -configuration Debug -destination "platform=watchOS Simulator,id=$WATCH_UDID" \
  -derivedDataPath build/apple-navigation-tests \
  -resultBundlePath build/watch-navigation.xcresult \
  -parallel-testing-enabled NO CODE_SIGN_IDENTITY=- test
```

Open the result bundle in Xcode for assertions and screenshot attachments `01-first-card`, `02-after-swipe-left`, and `03-after-swipe-right`. This test establishes native page changes; it does not test clearing or complication refresh.

## Physical signing and installation

Use your own Apple signing team and unique bundle identifiers. Complete account sign-in, device trust, pairing, and Developer Mode steps in Xcode and on the devices. The checked-in project uses placeholder identifiers and contains no signing credentials.

```bash
BUNDLE_ID=com.yourname.aiepocket DEVELOPMENT_TEAM=YOURTEAMID ruby scripts/configure_apple.rb
open ios/Runner.xcworkspace
```

`BUNDLE_ID` identifies the phone app. Setup derives `.watch` and `.watch.widgets` beneath it, plus `group.<BUNDLE_ID>`. Supply `APP_GROUP=group.your.existing.group` to reuse a registered group. The group belongs to **AIEWatch** and **AIEComplication**; the phone uses WatchConnectivity rather than the watch's shared filesystem.

In Signing & Capabilities, select the same team for **Runner**, **AIEWatch**, and **AIEComplication**, with automatic signing enabled and the same App Group on both watch targets. Use an Xcode version supporting the connected devices. During the recorded installation, Xcode 27.2 Device Hub pairing made Developer Mode available on the watch; device-specific provisioning then succeeded. A generic signed build without that watch registered in its profile was insufficient for installation.

Run **Runner** on the iPhone and **AIEWatch** on its paired watch. The iPhone's Watch app can also install the embedded watch app after Runner is installed. Keep local signing settings, device identifiers, certificates, and provisioning profiles out of commits. Complete the checks below and record results separately from simulator evidence.

## Verify the experience

Before tests that clear or replace an existing schedule, record the selection or use a dedicated test device pair.

1. Open both apps. Choose two talks on the phone and observe them arrive on the watch. A phone status of “queued” confirms only that the system accepted the latest snapshot.
2. On the 49 mm Apple Watch Ultra, swipe left and right through cards. Scroll long content and check the full title, presenter, location, day, and Pacific time, including with larger text enabled.
3. Disconnect the watch from the phone and reopen the watch app. Its last received schedule should remain visible. Edit the phone schedule while disconnected, reconnect, and verify the newest complete selection replaces the old one.
4. Remove every selected talk. Confirm the watch changes to its empty state after transfer and remains empty after reopening. Add a talk again and verify recovery.
5. Add **AIE Pocket** to supported circular and rectangular complication slots. Tap each to open the schedule. Observe current/next changes at talk boundaries. Change the phone selection with the watch face foregrounded and verify the complication updates without opening the watch app. WidgetKit controls refresh timing; updates are not guaranteed to be immediate.
6. Install the watch app after making selections on the phone, then reopen the companion. Confirm the saved selection transfers. Also verify a phone restart preserves it.

## Project wiring

`configure_apple.rb` preserves Flutter's Runner build phases and scheme. It adds the shared Swift model to all three targets, a WatchConnectivity bridge to Runner, watch application sources, and the complication source. Runner embeds `AIEWatch.app` under `Watch/`; AIEWatch embeds `AIEComplication.appex` under `PlugIns/`. The **AIEWatch** shared scheme builds the watch and complication directly.

After changing bundle IDs, App Group settings, or the Flutter platform scaffold, rerun the generator with the desired settings, then run its read-only `--check`. The checked-in default is `com.example.aiepocket`.

References: [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup), [Apple companion bundle identifier](https://developer.apple.com/documentation/bundleresources/information-property-list/wkcompanionappbundleidentifier), [WatchConnectivity application context](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)), [WidgetKit watch complications](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications), and [SwiftUI background WatchConnectivity](https://developer.apple.com/documentation/swiftui/backgroundtask/watchconnectivity).
