import Foundation

@main
struct SnapshotChecks {
    static func main() throws {
        typealias Payload = [String: Any]
        typealias TalkPayload = [String: String]

        let first: TalkPayload = [
            "id": "a", "title": "First", "presenter": "Presenter", "location": "Room A",
            "day": "2026-11-10", "start": "2026-11-10T10:00:00-08:00",
            "end": "2026-11-10T11:00:00-08:00", "track": "Code"
        ]
        let second: TalkPayload = [
            "id": "b", "title": "Second", "presenter": "Presenter", "location": "Room B",
            "day": "2026-11-10", "start": "2026-11-10T11:00:00-08:00",
            "end": "2026-11-10T12:00:00-08:00", "track": "Code"
        ]
        let base: Payload = [
            "schemaVersion": 1, "revision": 100, "eventName": "Conference",
            "timezone": "America/Los_Angeles", "generatedAt": "2026-11-10T16:00:00.123Z",
            "talks": [second, first]
        ]

        func data(_ payload: Payload) throws -> Data {
            try JSONSerialization.data(withJSONObject: payload)
        }
        func decode(_ payload: Payload) throws -> ScheduleSnapshot {
            try ScheduleSnapshot.decode(data(payload))
        }
        func date(_ value: String) -> Date { ScheduleDate.parse(value)! }
        func rejects(_ payload: Payload, _ reason: String) throws {
            let encoded = try data(payload)
            var rejected = false
            do { _ = try ScheduleSnapshot.decode(encoded) } catch { rejected = true }
            precondition(rejected, "Accepted invalid snapshot: \(reason)")
        }
        var completed = 0
        func check(_ name: String, _ body: () throws -> Void) rethrows {
            try body()
            completed += 1
            print("PASS: \(name)")
        }

        let schedule = try decode(base)
        try check("JSON round trip preserves the complete snapshot") {
            let encoded = try JSONEncoder().encode(schedule)
            let decoded = try ScheduleSnapshot.decode(encoded)
            precondition(decoded == schedule)
        }
        check("chronological order and exclusive talk-end boundaries") {
            precondition(schedule.sortedTalks.map(\.id) == ["a", "b"])
            precondition(schedule.currentOrNext(at: date("2026-11-10T17:00:00Z"))?.id == "a")
            precondition(schedule.currentOrNext(at: date("2026-11-10T18:30:00Z"))?.id == "a")
            precondition(schedule.currentOrNext(at: date("2026-11-10T19:00:00Z"))?.id == "b")
            precondition(schedule.currentOrNext(at: date("2026-11-10T20:00:00Z")) == nil)
            let talk = schedule.sortedTalks[0]
            precondition(!talk.isCurrent(at: date("2026-11-10T17:59:59Z")))
            precondition(talk.isCurrent(at: date("2026-11-10T18:00:00Z")))
            precondition(!talk.isCurrent(at: date("2026-11-10T19:00:00Z")))
        }
        try check("next talk is available during a gap") {
            var later = second
            later["start"] = "2026-11-10T11:30:00-08:00"
            var payload = base
            payload["talks"] = [later, first]
            let withGap = try decode(payload)
            let next = withGap.currentOrNext(at: date("2026-11-10T19:15:00Z"))!
            precondition(next.id == "b")
            precondition(!next.isCurrent(at: date("2026-11-10T19:15:00Z")))
        }
        try check("equal starts use stable IDs and overlapping talks remain available") {
            var sameStart = second
            // This UTC timestamp is the same instant as the first talk's Pacific start.
            sameStart["start"] = "2026-11-10T18:00:00Z"
            var payload = base
            payload["talks"] = [sameStart, first]
            let overlapping = try decode(payload)
            precondition(overlapping.sortedTalks.map(\.id) == ["a", "b"])
            precondition(overlapping.currentOrNext(at: date("2026-11-10T18:30:00Z"))?.id == "a")
            precondition(overlapping.currentOrNext(at: date("2026-11-10T19:00:00Z"))?.id == "b")
        }
        check("timeline boundaries are unique, ordered, and strictly in the future") {
            precondition(schedule.transitionDates(after: date("2026-11-10T17:00:00Z")) == [
                date("2026-11-10T18:00:00Z"), date("2026-11-10T19:00:00Z"),
                date("2026-11-10T20:00:00Z")
            ])
            precondition(schedule.transitionDates(after: date("2026-11-10T19:00:00Z")) == [
                date("2026-11-10T20:00:00Z")
            ])
            precondition(schedule.transitionDates(after: date("2026-11-10T20:00:00Z")).isEmpty)
        }
        try check("formatting follows conference timezone across UTC midnight and noon") {
            precondition(schedule.sortedTalks[0].timeLabel(timezone: schedule.timezone) == "10:00–11:00 AM")
            precondition(schedule.sortedTalks[1].timeLabel(timezone: schedule.timezone) == "11:00 AM–12:00 PM")
            var evening = first
            evening["start"] = "2026-11-11T01:00:00Z"
            evening["end"] = "2026-11-11T02:00:00Z"
            var payload = base
            payload["talks"] = [evening]
            let talk = try decode(payload).talks[0]
            precondition(talk.dayLabel(timezone: schedule.timezone) == "Tue, Nov 10")
            precondition(talk.timeLabel(timezone: schedule.timezone) == "5:00–6:00 PM")
        }
        check("ISO timestamps accept fractional seconds and reject missing offsets") {
            precondition(ScheduleDate.parse("2026-11-10T18:00:00.000Z") == date("2026-11-10T10:00:00-08:00"))
            precondition(ScheduleDate.parse("2026-11-10T10:00:00") == nil)
            precondition(ScheduleDate.parse("not-a-date") == nil)
        }

        try check("empty selection clears current talk and timeline") {
            var payload = base
            payload["talks"] = [TalkPayload]()
            let empty = try decode(payload)
            precondition(empty.sortedTalks.isEmpty)
            precondition(empty.currentOrNext(at: date("2026-11-10T18:30:00Z")) == nil)
            precondition(empty.transitionDates(after: date("2026-11-10T17:00:00Z")).isEmpty)
        }
        try check("incompatible schemas and nonpositive revisions are rejected") {
            for schema in [0, 2] {
                var payload = base
                payload["schemaVersion"] = schema
                try rejects(payload, "schema \(schema)")
            }
            for revision in [0, -1] {
                var payload = base
                payload["revision"] = revision
                try rejects(payload, "revision \(revision)")
            }
            var maximum = base
            maximum["revision"] = Int64.max
            let maximumRevision = try decode(maximum)
            precondition(maximumRevision.revision == Int64.max)
        }
        try check("invalid event metadata is rejected") {
            let invalid: [(String, Any)] = [
                ("eventName", " \n\t"), ("timezone", "Invalid/Zone"),
                ("generatedAt", "yesterday"), ("generatedAt", "2026-11-10T16:00:00")
            ]
            for (key, value) in invalid {
                var payload = base
                payload[key] = value
                try rejects(payload, key)
            }
        }
        try check("missing fields, wrong JSON types, and malformed JSON are rejected") {
            var missing = base
            missing.removeValue(forKey: "revision")
            try rejects(missing, "missing revision")
            for (key, value) in [("revision", "100"), ("talks", "not-an-array")] {
                var payload = base
                payload[key] = value
                try rejects(payload, "wrong type for \(key)")
            }
            var missingPresenter = first
            missingPresenter.removeValue(forKey: "presenter")
            var payload = base
            payload["talks"] = [missingPresenter]
            try rejects(payload, "missing presenter field")
            var rejected = false
            do { _ = try ScheduleSnapshot.decode(Data("{broken".utf8)) } catch { rejected = true }
            precondition(rejected, "Accepted malformed JSON")
        }
        try check("duplicate IDs and invalid talk fields are rejected") {
            var duplicate = base
            duplicate["talks"] = [first, first]
            try rejects(duplicate, "duplicate IDs")
            for (key, value) in [
                ("id", ""), ("title", " \n"), ("location", ""),
                ("start", "not-a-date"), ("end", "not-a-date"),
                ("end", first["start"]!), ("end", "2026-11-10T09:59:59-08:00")
            ] {
                var invalid = first
                invalid[key] = value
                var payload = base
                payload["talks"] = [invalid]
                try rejects(payload, "talk field \(key)")
            }
        }
        try check("logistics without a presenter and unknown additive fields remain compatible") {
            var logistics = first
            logistics["presenter"] = ""
            logistics["futureTalkField"] = "ignored"
            var payload = base
            payload["talks"] = [logistics]
            payload["futureEnvelopeField"] = true
            let decoded = try decode(payload)
            precondition(decoded.talks[0].presenter.isEmpty)
        }
        try check("cache reload via another defaults instance observes snapshots and clears") {
            let suite = "aie.snapshot-checks.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            precondition(ScheduleCache.load(from: defaults) == nil)
            ScheduleCache.save(try data(base), to: defaults)
            let reloadedDefaults = UserDefaults(suiteName: suite)!
            precondition(ScheduleCache.load(from: reloadedDefaults) == schedule)
            var cleared = base
            cleared["revision"] = 101
            cleared["talks"] = [TalkPayload]()
            ScheduleCache.save(try data(cleared), to: defaults)
            let snapshot = ScheduleCache.load(from: reloadedDefaults)!
            precondition(snapshot.revision == 101 && snapshot.talks.isEmpty)
        }
        try check("corrupt or unsupported cached data fails closed") {
            let suite = "aie.snapshot-checks.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            ScheduleCache.save(Data("not JSON".utf8), to: defaults)
            precondition(ScheduleCache.load(from: defaults) == nil)
            var unsupported = base
            unsupported["schemaVersion"] = 2
            ScheduleCache.save(try data(unsupported), to: defaults)
            precondition(ScheduleCache.load(from: defaults) == nil)
        }
        if CommandLine.arguments.count == 2 {
            try check("all bundled catalogue records decode with the native model") {
                let sourceData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
                let source = try JSONSerialization.jsonObject(with: sourceData) as! Payload
                let event = source["event"] as! Payload
                var payload = base
                payload["eventName"] = event["name"]
                payload["timezone"] = event["timezone"]
                payload["talks"] = source["talks"]
                let snapshot = try decode(payload)
                precondition(snapshot.talks.count == (source["talks"] as! [Any]).count)
                print("Decoded \(snapshot.talks.count) sourced talks")
            }
        }
        print("PASS: \(completed) native model and cache checks")
    }
}
