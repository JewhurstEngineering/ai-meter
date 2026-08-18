import SwiftUI
import AIMeterCore

@main
struct AIMeteriOSApp: App {
    @StateObject private var store: UsageStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = UsageStore()
        _store = StateObject(wrappedValue: store)
        BackgroundRefresh.register(store: store)
    }

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
                    if !AppLaunch.isAutomatedTest {
                        PhoneWatchBridge.shared.activate()
                    }
                    await store.bootstrap()
                    if !AppLaunch.isAutomatedTest {
                        BackgroundRefresh.schedule()
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await store.refresh() }
                        if !AppLaunch.isAutomatedTest {
                            BackgroundRefresh.schedule()
                        }
                    }
                }
        }
    }
}

private enum AppLaunch {
    static var isAutomatedTest: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
