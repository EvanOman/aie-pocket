import SwiftUI

private enum WatchPalette {
    static let accent = Color(red: 0.780, green: 0.969, blue: 0.549)
    static let ink = Color(red: 0.043, green: 0.055, blue: 0.071)
    static let muted = Color(red: 0.616, green: 0.655, blue: 0.706)
}

struct TalkCardsView: View {
    @ObservedObject var store: ScheduleStore
    @State private var selectedID: String?
    @ScaledMetric(relativeTo: .title3) private var emptyIconSize: CGFloat = 32

    private var talks: [ScheduleTalk] { store.snapshot?.sortedTalks ?? [] }

    var body: some View {
        Group {
            if let snapshot = store.snapshot, !talks.isEmpty {
                TabView(selection: $selectedID) {
                    ForEach(Array(talks.enumerated()), id: \.element.id) { index, talk in
                        TalkCard(talk: talk, snapshot: snapshot, position: index + 1, count: talks.count)
                            .tag(Optional(talk.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .onAppear { focusCurrentTalk() }
                .onChange(of: snapshot.revision) { _, _ in
                    if !talks.contains(where: { $0.id == selectedID }) { focusCurrentTalk() }
                }
            } else {
                emptyState
            }
        }
        .background(Color.black)
        .onOpenURL { _ in focusCurrentTalk() }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: emptyIconSize, weight: .medium))
                    .foregroundStyle(WatchPalette.accent)
                Text(store.snapshot == nil ? "Your day,\nat a glance." : "A fresh schedule.")
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Choose talks in AIE Pocket on your iPhone. They’ll appear here when your devices connect.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                if let error = store.errorMessage {
                    Text(error).font(.caption2).foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }

    private func focusCurrentTalk() {
        selectedID = store.snapshot?.currentOrNext(at: Date())?.id ?? talks.first?.id
    }
}

private struct TalkCard: View {
    let talk: ScheduleTalk
    let snapshot: ScheduleSnapshot
    let position: Int
    let count: Int
    @ScaledMetric(relativeTo: .caption2) private var detailFontSize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption2) private var metadataFontSize: CGFloat = 9
    @ScaledMetric(relativeTo: .caption2) private var positionFontSize: CGFloat = 10

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(talk.dayLabel(timezone: snapshot.timezone).uppercased())
                            .font(.system(size: metadataFontSize, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(WatchPalette.accent)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 2)
                        Text("\(position)/\(count)")
                            .font(.system(size: positionFontSize, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                    HStack(spacing: 5) {
                        if talk.isCurrent(at: timeline.date) {
                            Circle().fill(WatchPalette.accent).frame(width: 5, height: 5)
                        }
                        Text(talk.timeLabel(timezone: snapshot.timezone))
                            .font(.system(size: detailFontSize, weight: .semibold, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(talk.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if !talk.presenter.isEmpty {
                        Label(talk.presenter, systemImage: "person.fill")
                            .font(.system(size: detailFontSize, weight: .medium))
                            .foregroundStyle(WatchPalette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Label(talk.location, systemImage: "mappin.circle.fill")
                        .font(.system(size: detailFontSize, weight: .semibold))
                        .foregroundStyle(WatchPalette.accent)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.106, green: 0.141, blue: 0.137), in: RoundedRectangle(cornerRadius: 9))
                    if !talk.track.isEmpty {
                        Text(talk.track.uppercased())
                            .font(.system(size: metadataFontSize, weight: .bold, design: .rounded))
                            .tracking(0.7)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Times in \(snapshot.timezone)")
                        .font(.system(size: metadataFontSize))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Color(red: 0.085, green: 0.12, blue: 0.11), WatchPalette.ink], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(WatchPalette.accent.opacity(0.25), lineWidth: 1)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 22)
            .accessibilityLabel("Talk \(position) of \(count)")
        }
    }
}
