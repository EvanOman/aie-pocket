import Combine
import Foundation
import WatchConnectivity
import WidgetKit

/// WCSession callbacks enter the main queue before changing observable state.
final class ScheduleStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: ScheduleSnapshot?
    @Published private(set) var errorMessage: String?
    private var session: WCSession?

    override init() {
        snapshot = ScheduleCache.load()
        super.init()
        if WCSession.isSupported() {
            let connectivity = WCSession.default
            session = connectivity
            connectivity.delegate = self
            connectivity.activate()
        }
    }

    func refresh() {
        guard let session else { return }
        if session.activationState == .notActivated { session.activate() }
        receive(session.receivedApplicationContext)
    }

    func handleBackgroundConnectivity() async {
        // Keep the system's background task alive until activation and pending
        // context delivery settle. SwiftUI completes the task when this returns.
        let deadline = Date().addingTimeInterval(20)
        while !Task.isCancelled && Date() < deadline {
            let finished = await MainActor.run {
                self.refresh()
                guard let session = self.session else { return true }
                guard session.activationState == .activated && !session.hasContentPending else { return false }
                // Read again after observing delivery completion: a delegate
                // callback may have queued its save between the first read and
                // hasContentPending becoming false.
                self.refresh()
                return true
            }
            if finished { return }
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch { break }
        }
        // On cancellation or timeout, preserve any context already available.
        await MainActor.run { self.refresh() }
    }

    private func receive(_ context: [String: Any]) {
        guard let json = context["schedule"] as? String,
              let data = json.data(using: .utf8) else { return }
        do {
            let incoming = try ScheduleSnapshot.decode(data)
            // Late delivery must never resurrect a removed talk or an older schedule.
            if let snapshot, incoming.revision <= snapshot.revision { return }
            ScheduleCache.save(data)
            snapshot = incoming
            errorMessage = nil
            WidgetCenter.shared.reloadTimelines(ofKind: "AIESchedule")
        } catch {
            errorMessage = "Couldn’t read the new schedule. Your last saved talks are still available."
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            if let error { self?.errorMessage = error.localizedDescription }
            self?.receive(session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async { [weak self] in self?.receive(applicationContext) }
    }
}
