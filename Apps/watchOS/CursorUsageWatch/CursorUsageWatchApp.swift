import SwiftUI
import AIMeterCore

@main
struct CursorUsageWatchApp: App {
    @StateObject private var session = WatchSessionBridge()

    var body: some Scene {
        WindowGroup {
            WatchOverviewView()
                .environmentObject(session)
                .onAppear { session.activate() }
        }
    }
}
