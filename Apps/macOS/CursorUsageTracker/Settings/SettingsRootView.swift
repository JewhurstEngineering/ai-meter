import SwiftUI
import CursorUsageCore

struct SettingsRootView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            AuthenticationSettingsView()
                .tabItem { Label("Authentication", systemImage: "lock") }
            IncludedUsageSettingsView()
                .tabItem { Label("Included Usage", systemImage: "chart.bar") }
            PaidUsageSettingsView()
                .tabItem { Label("Paid Usage", systemImage: "creditcard") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
        .environmentObject(store)
    }
}
