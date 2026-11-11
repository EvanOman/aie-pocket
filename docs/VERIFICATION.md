# Verification

This record summarizes development checks performed on November 10–11, 2026. Simulator observations, physical-device observations, and browser previews are separate evidence. Build success alone does not establish WatchConnectivity delivery or complication behavior.

## Public-preparation checks — November 11

After removing personal catalogue fields and switching to placeholder signing identifiers, `scripts/check.sh` passed analysis, all **21 tests**, the web release build, and the static Xcode project check in an isolated Linux worktree. `scripts/check_swift.sh` passed model checks for all **112** records and native source parsing. All watch-facing session fields and **37** suggested IDs remain unchanged.

Browser checks at 1440×1000 and 390×844 confirmed search, choosing talks, generic evening-event details, day/topic filters, persisted choices, watch-preview navigation, and clearing. The new placeholder signing configuration has not been compiled or installed with Xcode; the Apple results below describe the preceding development configuration and must be repeated with a developer's own identifiers before device installation.

## Toolchains and builds

| Scope | Recorded result |
| --- | --- |
| Flutter | Flutter 3.38.10 / Dart 3.10.9: analysis clean, **21 tests passed** after the day-navigation update, and web release built. |
| Native simulator builds | Xcode 26.6 (17F113), iOS/watchOS 26.5 SDKs: Runner, AIEWatch, and the embedded complication built successfully. Both unsigned compilation and ad-hoc signed simulator builds passed. |
| Native physical builds | Signed Release builds passed for the iPhone with Xcode 26.6 and for the Watch with Xcode 27.2 (27B52), using its watchOS 27.2 SDK. |
| Mac dependencies | CocoaPods 1.17.0, Ruby 3.3.12, and xcodeproj 1.28.1 were used for the Mac checks. Linux project validation also passed with xcodeproj 1.27.0. |
| Shared Swift model | `scripts/check_swift.sh` decoded all 112 catalogue records and passed chronology, current/next boundaries, Pacific time, timeline transitions, empty clearing, schema, duplicates, and duration checks. Swift 6.0.3 on Linux also compiled and ran these checks. |
| Swift syntax | Native source parsing passed. Linux parsing does not typecheck Apple frameworks; the Mac builds provide that evidence. |
| Xcode structure | `ruby scripts/configure_apple.rb --check` passed source membership, dependencies, embedding, bundle relationships, App Groups, URL scheme, plist, and asset checks. |
| Clean setup | An export of tracked source passed `flutter pub get` followed by the static Apple project check. The Mac check script generates the excluded plugin registrant before validating source references. |

The Runner dependency cycle was resolved by placing **Embed Watch Content** before Flutter's **Thin Binary** phase; the generator preserves this ordering. Unsigned simulator builds did not register the watch App Group container. Runtime checks therefore used `CODE_SIGN_IDENTITY=-`, which registered the group for the app and complication.

See [BUILD.md](BUILD.md) for the commands to reproduce builds and tests with local simulator identifiers and signing configuration.

## Companion and browser

- The 21 Flutter tests cover catalogue loading, optional recommendations, chronological ordering, conflicts, persistent empty selection, rapid writes, snapshot revisions, retry recovery, method-channel payloads, and phone/desktop interactions. Day-navigation cases include Pacific midnight, exclusive end times, before/after conference boundaries, empty selection, and jumping from another day with a search active.
- A search-focus regression was fixed with stable widget identity. A widget test and actual iPhone simulator typing confirmed that the query and focus survive the empty-selection starter panel disappearing.
- Chrome interactions at **1440×1000** and **390×844** exercised recommendations, speaker search, day/topic filtering, selection/removal, overlap warnings, details, watch-preview navigation, and clearing. Reloading retained both edited selections and an explicitly empty selection.
- The day-navigation update was checked at **390×844**: complete day/date labels remained visible, and **Jump to now** scrolled the highlighted current session fully into view. The same update built, installed, and launched on the physical iPhone.

Browser results establish companion behavior and browser persistence. The browser watch is a design preview; it does not send a schedule to Apple Watch.

## Paired simulator observations

The principal test pair was an iPhone 17 simulator and a **49 mm Apple Watch Ultra 3** simulator, both using the 26.5 runtimes.

| Check | Observed result |
| --- | --- |
| Transfer and persistence | Selected talks arrived through WatchConnectivity, survived a phone restart, and remained on the watch after an offline restart. Reinstalling the watch app after making phone selections also received the saved selection. |
| Card readability | The complete border remained visible at default and maximum watch text sizes. Crown scrolling exposed full titles, presenter lists, rooms, and the Pacific-time footer. |
| Native horizontal swiping | `AIEWatchUITests/TalkNavigationTests/testSwipeBetweenReceivedTalks` passed: **1 test, 0 failures**. It used two talks actually received from the companion and verified `1/2 → swipe left → 2/2 → swipe right → 1/2`, including hittable titles and hidden opposite positions. The final run took 17.294 seconds. |
| Clearing and recovery | Clearing on the phone produced an empty received snapshot and the watch's empty state. That state survived a watch restart with the phone shut down. Adding talks back restored the received schedule, and the native swipe test passed again. |
| Complication families | Circular and rectangular complications rendered on the Modular face. Tapping either opened the schedule. |
| Background selection refresh | Changing the phone selection while the watch face remained foregrounded updated the received cache and both complications without opening the watch app. No guaranteed update interval is claimed. |
| Disconnected replacement | One attempt retained stale data until the phone companion reopened. A later retest, with the complication face active and the phone app continuously foregrounded, received the newest disconnected selection after watch restart without opening either app again. Physical-device retesting remains necessary. |

Earlier receipt and offline-restart checks also ran on a 40 mm simulator. Most layout and interaction evidence is specific to the 49 mm Ultra; broader watch-size coverage is not established.

## Physical-device observations

The companion installed and launched on an **iPhone 16 Pro running iOS 27.2**. The native watch app installed and launched on a **49 mm Apple Watch Ultra running watchOS 27.0.1** after device pairing, Developer Mode, and device-specific provisioning were completed with Xcode 27.2.

The physical watch received **38 talks**. Device Hub screen sharing showed the title, presenter, day/time, and complete card border for a received talk, and a later card showed a full location. This establishes physical receipt and rendering. It does not establish automated swipe behavior or the remaining checks below.

The tracked [phone screenshot](screenshots/aie-pocket-iphone.png) is from the iPhone simulator. The [Ultra overview](screenshots/aie-pocket-ultra.png) and [Ultra talk](screenshots/aie-pocket-ultra-talk.png) are physical-device captures. The purple status icon indicates Device Hub screen sharing. These are unedited app captures; long watch content scrolls within the card border.

## Remaining checks

| Check | Status |
| --- | --- |
| Physical horizontal swipe and long-card scrolling | Receipt and rendering observed; the full interaction sequence remains unverified on hardware. |
| Physical offline persistence, disconnected replacement, clear-to-empty, and add-back | Simulator checks passed as described above; physical checks remain unverified. |
| Physical complication rendering, tap-to-open, and background selection refresh | Simulator checks passed; physical checks remain unverified. |
| Complication current/next transition at talk boundaries | Shared-model boundary tests passed; runtime transition observation remains pending on simulators and physical devices. |

Use the [experience checklist](BUILD.md#verify-the-experience) to record new observations. Keep actual received state distinct from the phone's queued status, and separate simulator results from hardware results.
