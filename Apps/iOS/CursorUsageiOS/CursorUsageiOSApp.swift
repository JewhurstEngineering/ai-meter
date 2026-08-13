import SwiftUI
import CursorUsageCore

@main
struct CursorUsageiOSApp: App {
    @StateObject private var store = UsageStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .appThemed(store.preferences)
                .task {
                    store.onWidgetSnapshotWritten = {
                        WidgetReload.afterWritingSnapshot()
                        PhoneWatchBridge.shared.sendLatest()
                    }
                    PhoneWatchBridge.shared.activate()
                    BackgroundRefresh.register(store: store)
                    await store.bootstrap()
                    BackgroundRefresh.schedule()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refresh() }
                        BackgroundRefresh.schedule()
                    }
                }
        }
    }
}
