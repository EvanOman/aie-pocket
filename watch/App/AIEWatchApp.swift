import SwiftUI

@main
struct AIEWatchApp: App {
    @StateObject private var store = ScheduleStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            TalkCardsView(store: store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refresh() }
        }
        .backgroundTask(.watchConnectivity) {
            await store.handleBackgroundConnectivity()
        }
    }
}
