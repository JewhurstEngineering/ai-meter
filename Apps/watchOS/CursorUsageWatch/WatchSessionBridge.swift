import SwiftUI
import WatchConnectivity
import WidgetKit
import CursorUsageCore

@MainActor
final class WatchSessionBridge: NSObject, WCSessionDelegate, ObservableObject {
    @Published var snapshot: WidgetSnapshot?

    func activate() {
        snapshot = WidgetSnapshotStore.readWatchLocal()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        apply(session.receivedApplicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        apply(applicationContext)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
    }

    nonisolated private func apply(_ dict: [String: Any]) {
        guard let data = dict[WidgetSnapshotStore.watchTransferKey] as? Data,
              let snap = WidgetSnapshotStore.snapshot(from: data)
        else { return }
        WidgetSnapshotStore.writeWatchLocal(snap)
        Task { @MainActor in
            snapshot = snap
            WidgetReload.afterWritingSnapshot()
        }
    }
}
