import Foundation
import WatchConnectivity
import AIMeterCore

/// Pushes sanitized `WidgetSnapshot` JSON to the paired Watch. Never sends tokens.
@MainActor
final class PhoneWatchBridge: NSObject, WCSessionDelegate {
    static let shared = PhoneWatchBridge()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendLatest() {
        guard let snap = WidgetSnapshotStore.read(),
              let data = try? WidgetSnapshotStore.data(from: snap)
        else { return }
        send(data: data)
    }

    private func send(data: Data) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext([WidgetSnapshotStore.watchTransferKey: data])
        if session.isReachable {
            session.transferUserInfo([WidgetSnapshotStore.watchTransferKey: data])
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if activationState == .activated {
                sendLatest()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            if session.isReachable {
                sendLatest()
            }
        }
    }
}
