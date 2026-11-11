import Foundation

@main
struct SnapshotChecks {
    static func main() throws {
        let base: [String: Any] = [
            "schemaVersion": 1,
            "revision": 100,
            "eventName": "Conference",
            "timezone": "America/Los_Angeles",
            "generatedAt": "2026-11-10T16:00:00.123Z",
            "talks": [
                ["id": "b", "title": "Second", "presenter": "Presenter", "location": "Room B", "day": "2026-11-10", "start": "2026-11-10T11:00:00-08:00", "end": "2026-11-10T12:00:00-08:00", "track": "Code"],
                ["id": "a", "title": "First", "presenter": "Presenter", "location": "Room A", "day": "2026-11-10", "start": "2026-11-10T10:00:00-08:00", "end": "2026-11-10T11:00:00-08:00", "track": "Code"]
            ]
        ]
        func data(_ value: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: value) }
        let schedule = try ScheduleSnapshot.decode(data(base))
        precondition(schedule.sortedTalks.map(\.id) == ["a", "b"])
        precondition(schedule.currentOrNext(at: ScheduleDate.parse("2026-11-10T17:00:00Z")!)?.id == "a")
        precondition(schedule.currentOrNext(at: ScheduleDate.parse("2026-11-10T18:30:00Z")!)?.id == "a")
        precondition(schedule.currentOrNext(at: ScheduleDate.parse("2026-11-10T19:00:00Z")!)?.id == "b")
        precondition(schedule.currentOrNext(at: ScheduleDate.parse("2026-11-10T20:00:00Z")!) == nil)
        precondition(schedule.sortedTalks[0].timeLabel(timezone: schedule.timezone) == "10:00–11:00 AM")
        precondition(schedule.transitionDates(after: ScheduleDate.parse("2026-11-10T17:00:00Z")!).count == 3)
        var empty = base
        empty["talks"] = []
        let cleared = try ScheduleSnapshot.decode(data(empty))
        precondition(cleared.talks.isEmpty)
        var unsupported = base
        unsupported["schemaVersion"] = 2
        do { _ = try ScheduleSnapshot.decode(data(unsupported)); fatalError("Accepted incompatible schema") } catch {}
        var duplicate = base
        let first = (base["talks"] as! [[String: String]])[0]
        duplicate["talks"] = [first, first]
        do { _ = try ScheduleSnapshot.decode(data(duplicate)); fatalError("Accepted duplicate IDs") } catch {}
        var broken = base
        var brokenTalk = first
        brokenTalk["end"] = brokenTalk["start"]
        broken["talks"] = [brokenTalk]
        do { _ = try ScheduleSnapshot.decode(data(broken)); fatalError("Accepted invalid duration") } catch {}
        var logistics = base
        var logisticsTalk = first
        logisticsTalk["presenter"] = ""
        logistics["talks"] = [logisticsTalk]
        let decodedLogistics = try ScheduleSnapshot.decode(data(logistics))
        precondition(decodedLogistics.talks[0].presenter.isEmpty)
        precondition(schedule.sortedTalks[1].timeLabel(timezone: schedule.timezone) == "11:00 AM–12:00 PM")
        if CommandLine.arguments.count == 2 {
            let sourceData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let source = try JSONSerialization.jsonObject(with: sourceData) as! [String: Any]
            let event = source["event"] as! [String: Any]
            var sourcedPayload = base
            sourcedPayload["eventName"] = event["name"]
            sourcedPayload["timezone"] = event["timezone"]
            sourcedPayload["talks"] = source["talks"]
            let sourceSnapshot = try ScheduleSnapshot.decode(data(sourcedPayload))
            precondition(sourceSnapshot.talks.count == (source["talks"] as! [Any]).count)
            print("PASS: decoded all \(sourceSnapshot.talks.count) sourced talks with the native model")
        }
        print("PASS: chronology, current/next boundaries, event timezone, timeline transitions, empty clear, schema, duplicates, duration")
    }
}
