import AppKit
import SwiftUI
import CursorUsageCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = UsageStore()
    private let statusItem = StatusItemController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store.onWidgetSnapshotWritten = { WidgetReload.afterWritingSnapshot() }
        statusItem.start(store: store)
    }

    nonisolated func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                AppActivation.openSettingsViaLinkFallback()
            }
        }
        return true
    }
}

@main
struct CursorUsageTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu bar UI is hosted by StatusItemController (AppKit) so the label
        // is not clipped the way SwiftUI MenuBarExtra truncates with "…".
        Settings {
            SettingsRootView()
                .environmentObject(appDelegate.store)
                .frame(minWidth: 900, idealWidth: 960, minHeight: 560, idealHeight: 620)
                .onAppear {
                    AppActivation.scheduleSettingsFocus()
                }
        }
    }
}
