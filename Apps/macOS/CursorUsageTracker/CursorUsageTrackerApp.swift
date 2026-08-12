import SwiftUI
import CursorUsageCore

@main
struct CursorUsageTrackerApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(store)
                .frame(width: 340)
        } label: {
            MenuBarLabelView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environmentObject(store)
                .frame(width: 520, height: 440)
        }
    }
}
