# Run the same portable gate used by GitHub Actions.
default: check

# Familiar full-check aliases from pystd / tsstd.
fc: check

ci: check

check:
    REQUIRE_APPLE_PROJECT_CHECK=1 bundle exec ./scripts/check.sh

# Format and apply analyzer fixes; never run automatically in CI.
fix:
    ./scripts/fix.sh

# Swift must be installed, or run the pinned container command in docs/TESTING.md.
swift:
    ./scripts/check_swift.sh

# Requires macOS, Xcode, and bundle install.
apple:
    bundle exec ./scripts/check_apple_on_mac.sh
