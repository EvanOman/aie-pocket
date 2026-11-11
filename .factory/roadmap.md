# Product scope

- Choose conference talks in the Flutter companion, retain selections across restarts, show conflicts, and order selected talks by event time.
- Swipe native Apple Watch cards showing title, presenter, location, and Pacific time, with scrollable long content and an offline cache.
- Replace the watch schedule with complete versioned snapshots, including clearing every selection.
- Open the schedule from circular and rectangular complications, and display the current or next talk.

## Current evidence and remaining work

Companion checks, browser interactions, Apple builds, shared-model checks, and simulator swipe/offline/clear/complication checks have passed. Physical iPhone and Ultra installation, schedule receipt, and rendering have been observed.

Physical swipe, offline replacement, clearing, and complication behavior remain unverified. Runtime complication transitions at talk boundaries also remain open. See [the verification record](../docs/VERIFICATION.md) for exact scope and [the build guide](../docs/BUILD.md) for repeatable checks. Browser previews and compilation do not establish hardware behavior.
