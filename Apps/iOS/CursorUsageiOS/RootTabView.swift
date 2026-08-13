import SwiftUI
import CursorUsageCore

struct RootTabView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Overview", systemImage: "chart.bar.fill") }
            AccountsView()
                .tabItem { Label("Accounts", systemImage: "person.2.fill") }
            PhoneSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
