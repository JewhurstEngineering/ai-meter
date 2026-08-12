import SwiftUI
import CursorUsageCore

@main
struct CursorUsageTrackerApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(store)
        } label: {
            MenuBarLabelView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environmentObject(store)
                .frame(minWidth: 720, idealWidth: 760, minHeight: 520, idealHeight: 560)
        }
    }
}
