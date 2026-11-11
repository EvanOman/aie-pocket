import Flutter
import Foundation
import WatchConnectivity

/// The iPhone is the only schedule writer. All mutable state lives on the main queue.
final class ScheduleBridge: NSObject, WCSessionDelegate {
    private let channel: FlutterMethodChannel
    private var session: WCSession?
    private var latest: ScheduleSnapshot?
    private var latestData: Data?
    private var lastQueuedRevision: Int64?
    private var transferError: String?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "aie_watch/schedule", binaryMessenger: messenger)
        super.init()
        if let data = UserDefaults.standard.data(forKey: ScheduleCache.key),
           let snapshot = try? ScheduleSnapshot.decode(data) {
            latest = snapshot
            latestData = data
        }
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { return }
            switch call.method {
            case "publishSchedule":
                guard let json = call.arguments as? String,
                      let data = json.data(using: .utf8) else {
                    result(FlutterError(code: "INVALID_SCHEDULE", message: "Expected a schedule JSON string.", details: nil))
                    return
                }
                do {
                    let snapshot = try ScheduleSnapshot.decode(data)
                    if let latest = self.latest,
                       snapshot.revision < latest.revision ||
                        (snapshot.revision == latest.revision && snapshot != latest) {
                        throw ScheduleError.staleSnapshot
                    }
                    // Persist before attempting delivery, including a deliberately empty schedule.
                    ScheduleCache.save(data, to: .standard)
                    self.latest = snapshot
                    self.latestData = data
                    self.queueLatest()
                    result(self.status())
                } catch {
                    result(FlutterError(code: "INVALID_SCHEDULE", message: error.localizedDescription, details: nil))
                }
            case "status":
                self.refresh()
                result(self.status())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        if WCSession.isSupported() {
            let connectivity = WCSession.default
            session = connectivity
            connectivity.delegate = self
            connectivity.activate()
        }
    }

    func refresh() {
        guard let session else { return }
        if session.activationState == .notActivated {
            session.activate()
        }
        queueLatest()
    }

    private func queueLatest(force: Bool = false) {
        guard let session, session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let latest, let data = latestData,
              force || lastQueuedRevision != latest.revision,
              let json = String(data: data, encoding: .utf8) else { return }
        do {
            // Reachability is intentionally not required: the system delivers when possible.
            try session.updateApplicationContext(["schedule": json])
            lastQueuedRevision = latest.revision
            transferError = nil
        } catch {
            transferError = error.localizedDescription
        }
    }

    private func status() -> [String: String] {
        guard let session else {
            return ["state": "unavailable", "message": "Apple Watch sync is available on a paired iPhone."]
        }
        guard session.activationState == .activated else {
            if let transferError { return ["state": "error", "message": transferError] }
            return ["state": "queued", "message": "Connecting to Apple Watch. Your schedule is saved on this iPhone."]
        }
        guard session.isPaired else {
            return ["state": "notPaired", "message": "Pair an Apple Watch with this iPhone to send your schedule."]
        }
        guard session.isWatchAppInstalled else {
            return ["state": "notInstalled", "message": "Install AIE Pocket on your Apple Watch. Your schedule is saved on this iPhone."]
        }
        if let transferError { return ["state": "error", "message": "Schedule saved. Transfer will retry: \(transferError)"] }
        if latest != nil {
            return ["state": "queued", "message": "Queued for Apple Watch. Delivery happens when your devices can connect."]
        }
        return ["state": "ready", "message": "Apple Watch is ready. Choose talks to send your schedule."]
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.transferError = error?.localizedDescription
            self?.queueLatest(force: true)
        }
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in self?.queueLatest(force: true) }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.lastQueuedRevision = nil
            session.activate()
        }
    }
}
