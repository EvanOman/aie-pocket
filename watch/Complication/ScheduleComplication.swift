import SwiftUI
import WidgetKit

struct ScheduleEntry: TimelineEntry {
    let date: Date
    let snapshot: ScheduleSnapshot?
    var talk: ScheduleTalk? { snapshot?.currentOrNext(at: date) }
}

struct ScheduleProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScheduleEntry {
        ScheduleEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
        completion(ScheduleEntry(date: Date(), snapshot: ScheduleCache.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
        let now = Date()
        let snapshot = ScheduleCache.load()
        // Entries at every start and end prevent a finished talk remaining on the face.
        let transitions = Array((snapshot?.transitionDates(after: now) ?? []).prefix(80))
        let entries = ([now] + transitions).map { ScheduleEntry(date: $0, snapshot: snapshot) }
        let nextRefresh = transitions.last?.addingTimeInterval(60) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(nextRefresh)))
    }
}

struct ScheduleComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScheduleEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 1) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .semibold))
                        if let talk = entry.talk, let date = talk.startDate {
                            Text(shortTime(date))
                                .font(.system(size: 11, weight: .bold))
                                .minimumScaleFactor(0.7)
                        } else {
                            Text("AIE").font(.system(size: 11, weight: .bold))
                        }
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 2) {
                    if let talk = entry.talk, let snapshot = entry.snapshot {
                        Text(talk.isCurrent(at: entry.date) ? "NOW · \(talk.location)" : "NEXT · \(talk.timeLabel(timezone: snapshot.timezone))")
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                        Text(talk.title).font(.headline).lineLimit(2)
                        if !talk.presenter.isEmpty {
                            Text(talk.presenter).font(.caption2).lineLimit(1)
                        }
                    } else {
                        Text("AIE POCKET").font(.caption2.weight(.bold))
                        Text(emptyLabel).font(.headline)
                        Text("Tap to open your schedule").font(.caption2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(for: .widget) { Color.black }
        .widgetURL(URL(string: "aiewatch://schedule"))
    }

    private var emptyLabel: String {
        guard let snapshot = entry.snapshot, !snapshot.talks.isEmpty else { return "Choose your talks" }
        return "All talks finished"
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: entry.snapshot?.timezone ?? "UTC")
        formatter.dateFormat = "h:mm"
        return formatter.string(from: date)
    }
}

@main
struct ScheduleComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AIESchedule", provider: ScheduleProvider()) { entry in
            ScheduleComplicationView(entry: entry)
        }
        .configurationDisplayName("AIE Pocket")
        .description("Your current or next talk. Tap to swipe through your schedule.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
