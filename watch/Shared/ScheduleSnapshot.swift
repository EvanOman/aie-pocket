import Foundation

/// The complete, versioned schedule exchanged by the phone, watch and complication.
struct ScheduleSnapshot: Codable, Equatable {
    let schemaVersion: Int
    let revision: Int64
    let eventName: String
    let timezone: String
    let generatedAt: String
    let talks: [ScheduleTalk]

    static func decode(_ data: Data) throws -> ScheduleSnapshot {
        let snapshot = try JSONDecoder().decode(ScheduleSnapshot.self, from: data)
        guard snapshot.schemaVersion == 1,
              snapshot.revision > 0,
              !snapshot.eventName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              TimeZone(identifier: snapshot.timezone) != nil,
              ScheduleDate.parse(snapshot.generatedAt) != nil,
              Set(snapshot.talks.map(\.id)).count == snapshot.talks.count,
              snapshot.talks.allSatisfy({ $0.isValid }) else {
            throw ScheduleError.invalidSnapshot
        }
        return snapshot
    }

    var sortedTalks: [ScheduleTalk] {
        talks.sorted {
            let lhs = $0.startDate ?? .distantPast
            let rhs = $1.startDate ?? .distantPast
            return lhs == rhs ? $0.id < $1.id : lhs < rhs
        }
    }

    func currentOrNext(at date: Date) -> ScheduleTalk? {
        sortedTalks.first { ($0.endDate ?? .distantPast) > date }
    }

    func transitionDates(after date: Date) -> [Date] {
        Array(Set(talks.flatMap { [$0.startDate, $0.endDate].compactMap { $0 } }))
            .filter { $0 > date }
            .sorted()
    }
}

struct ScheduleTalk: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let presenter: String
    let location: String
    let day: String
    let start: String
    let end: String
    let track: String

    var startDate: Date? { ScheduleDate.parse(start) }
    var endDate: Date? { ScheduleDate.parse(end) }

    var isValid: Bool {
        guard !id.isEmpty, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !location.isEmpty,
              let startDate, let endDate, startDate < endDate else { return false }
        return true
    }

    func isCurrent(at date: Date) -> Bool {
        guard let startDate, let endDate else { return false }
        return startDate <= date && date < endDate
    }

    func timeLabel(timezone: String) -> String {
        guard let startDate, let endDate else { return "Time unavailable" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone)
        formatter.dateFormat = "a"
        let samePeriod = formatter.string(from: startDate) == formatter.string(from: endDate)
        formatter.dateFormat = samePeriod ? "h:mm" : "h:mm a"
        let startText = formatter.string(from: startDate)
        formatter.dateFormat = "h:mm a"
        return "\(startText)–\(formatter.string(from: endDate))"
    }

    func dayLabel(timezone: String) -> String {
        guard let startDate else { return day }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: timezone)
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: startDate)
    }
}

enum ScheduleDate {
    static func parse(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

enum ScheduleError: LocalizedError {
    case invalidSnapshot
    case staleSnapshot

    var errorDescription: String? {
        switch self {
        case .invalidSnapshot: return "The schedule format is not supported. Update the companion and watch apps together."
        case .staleSnapshot: return "A newer schedule is already saved. Reopen the companion app and try again."
        }
    }
}

enum ScheduleCache {
    static let key = "aie.schedule.snapshot.v1"

    static var sharedDefaults: UserDefaults {
        let group = Bundle.main.object(forInfoDictionaryKey: "ScheduleAppGroup") as? String
            ?? "group.com.example.aiepocket"
        return UserDefaults(suiteName: group) ?? .standard
    }

    static func load(from defaults: UserDefaults = sharedDefaults) -> ScheduleSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? ScheduleSnapshot.decode(data)
    }

    static func save(_ data: Data, to defaults: UserDefaults = sharedDefaults) {
        defaults.set(data, forKey: key)
    }
}
