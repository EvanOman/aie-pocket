# Conference data

`assets/schedule.json` is an offline snapshot for **AI Engineer Code 2026**, retrieved November 10, 2026 and normalized from Evan's conference field guide. Public event sources are the [official schedule](https://ai.engineer/code/2026/schedule), [session catalogue](https://ai.engineer/code/2026/sessions.json), and [speaker catalogue](https://ai.engineer/code/2026/speakers.json). Individual entries retain their source event URLs. This is an independent companion app, not an official conference product.

The snapshot contains 112 sessions on November 10–12 at Hilton San Francisco Union Square, including workshops, breaks, logistics, and evening events. Every start/end timestamp retains its explicit `-08:00` offset. The app displays Pacific conference time independently of the phone's timezone. The verification, platform, workflow, and other topics are field-guide categories, not venue stages.

The field guide supplied short summaries and an optional 37-session suggested path. **Use suggested path** selects that set; the companion starts empty. Recommendations are editorial suggestions, not registration confirmations or the user's saved schedule. Personal RSVP statuses, itinerary notes, and private source-project identifiers are not part of this public catalogue. Browser-preview choices stay in that browser; the installed iPhone companion sends its own choices to Apple Watch.

Some logistics entries have no presenter. Four evening events direct readers to their event page for venue and check-in details; no venue was inferred. The snapshot is not a live feed. Check official event pages for changes and entry requirements.

The catalogue is excluded from the app code's MIT license. Event names, titles, speaker names, venues, times, and referenced content remain attributed to their sources; no license to talk recordings, slides, abstracts, or conference branding is granted here. See [third-party notices](../THIRD_PARTY_NOTICES.md).

To refresh the catalogue, use an authorized source and preserve stable session IDs so existing choices remain meaningful. Keep timestamps explicit, retain source URLs, omit personal registration data, and run `scripts/check.sh` and `scripts/check_swift.sh`. Only ID, title, presenter, location, day, start/end, and topic are transferred to the watch. The full 112-session watch payload is approximately 30 KB.
