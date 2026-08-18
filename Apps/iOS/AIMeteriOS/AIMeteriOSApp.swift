import SwiftUI
import AIMeterCore

@main
struct AIMeteriOSApp: App {
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
                    let uiTesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")
                    if !uiTesting {
                        PhoneWatchBridge.shared.activate()
                        BackgroundRefresh.register(store: store)
                    }
                    await store.bootstrap()
                    if !uiTesting {
                        BackgroundRefresh.schedule()
                    }
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
