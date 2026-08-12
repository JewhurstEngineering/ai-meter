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
                .frame(minWidth: 760, idealWidth: 820, minHeight: 560, idealHeight: 600)
                .onAppear {
                    AppActivation.focusSettingsWindows()
                }
        }
    }
}
