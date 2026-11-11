# Tests and CI

This project adapts the pystd/tsstd workflow to its existing Flutter/Dart and Swift toolchains. It does not add Python or TypeScript tooling to the app.

| Standard | Flutter / Apple equivalent |
| --- | --- |
| Reproducible dependencies | Flutter 3.38.10 / Dart 3.10.9, `flutter pub get --enforce-lockfile`, frozen `Gemfile.lock`, and `pod install --deployment` |
| Formatting check separate from fixes | `dart format --output=none --set-exit-if-changed`; changes only through `scripts/fix.sh` |
| Lint and type checks | Flutter lints plus strict casts, inference, and raw types; warnings and infos fail analysis |
| Behavioral tests | Flutter unit/widget tests plus portable Swift snapshot/cache checks |
| Coverage | `coverage/lcov.info` from the Dart tests, uploaded as a CI artifact |
| Repeatable commands | `just fc` / `just ci` / `just check` call the same check script as CI; `just fix` is separate |
| Restricted automation | Read-only repository contents, no signing or deployment secrets, SHA-pinned direct actions, timeouts, canceled superseded runs |

## Run locally

Use the pinned Flutter SDK on `PATH`. `FLUTTER_BIN` and `DART_BIN` can override its executables. On a machine with Ruby development headers available, install the locked Apple tooling:

```sh
gem install bundler -v 2.6.9
bundle install
just fc
```

Without Just, run `REQUIRE_APPLE_PROJECT_CHECK=1 bundle exec ./scripts/check.sh`. This resolves the existing Dart lockfile, checks formatting without writing it, analyzes, runs the complete Flutter suite with coverage, builds `build/web`, and validates the Xcode project. Generated caches, coverage, and build output are ignored; checks do not autofix source or update dependency versions.

For Flutter-only development without Ruby tooling, `./scripts/check.sh` runs the Flutter gate and explicitly reports that static Apple validation was skipped. CI installs the locked Ruby dependencies and requires that validation; a missing or unloadable gem fails the job. Use `just fix` only when you intend to apply Dart analyzer fixes and formatting, then rerun the checks.

Run the Swift suite with `just swift` / `./scripts/check_swift.sh`, or use the same pinned Linux image as CI:

```sh
docker run --rm --network none -v "$PWD:/src:ro" -w /src \
  swift:6.0.3-jammy@sha256:95f6ef898992dc840b35517e780f6f6db9661432775ab0b33cc0a531ea749bdb \
  bash scripts/check_swift.sh
```

On a Mac with Xcode, run `just apple` / `bundle exec ./scripts/check_apple_on_mac.sh`. See [BUILD.md](BUILD.md) for simulator pairing and physical installation. The script uses the locked Pods and compiles Runner, the watch app, and the complication without signing credentials.

## Suite boundaries

The **40 Flutter tests** cover catalogue/model validation, conference-time boundaries, stored selection encoding/corruption, empty clears, retry and ordered-write behavior, method-channel replies/failures, filtering and day navigation, clear cancellation, and watch-preview page changes as the schedule shrinks or refills. Preference tests fake only the plugin storage boundary; controller tests fake storage/transport to make failure and ordering cases deterministic.

The **16 named Swift checks** cover JSON compatibility and malformed payloads, revisions, stable ordering, overlaps/gaps, exact timeline boundaries, Pacific-time formatting, cache reload/clearing/corruption within one process, and decoding all 112 real catalogue entries. The runner exits nonzero on a failed assertion and cleans up isolated cache suites. It also parses native Swift sources, including the watch UI tests.

Coverage is evidence for finding gaps, not a substitute for behavior assertions. The LCOV report covers Dart code exercised by the suite; there is no arbitrary percentage gate or automatic badge-commit bot. Swift, Apple frameworks, and physical WatchConnectivity are not included in Dart coverage.

## GitHub Actions

[CI runs](https://github.com/EvanOman/aie-pocket/actions/workflows/ci.yml) on pushes to `main`, pull requests, and manual dispatch:

1. **Flutter analysis, tests, and web** — Ubuntu, pinned Flutter/Ruby, the same `scripts/check.sh`, and a retained Dart LCOV artifact.
2. **Swift snapshot and cache tests** — the digest-pinned Swift 6.0.3 Linux container, model/cache checks, and Swift syntax parsing.
3. **Unsigned iPhone and watchOS builds** — macOS 26, Xcode 26.6, locked Ruby/Pods, shared-model checks, and real Apple SDK compilation. Its build log is retained even when compilation fails.

Flutter and Apple jobs also fail if validation changes tracked files. Direct action revisions, SDK versions, and dependency locks should be updated deliberately and tested together. Hosted-runner images can change; Xcode availability is checked by the actual build.

These jobs do not install or launch apps on paired devices. The existing native watch swipe XCTest requires two talks actually received from the companion and is run manually on a prepared Ultra simulator. Physical delivery, offline recovery, clear-to-empty, complication refresh, and time-boundary transitions retain the verification limits in [VERIFICATION.md](VERIFICATION.md). No CI job changes repository visibility or publishes an app.
