import SwiftUI
import AIMeterCore

enum PhoneRootTab: String, CaseIterable {
    case overview = "Overview"
    case accounts = "Accounts"
    case settings = "Settings"

    var systemImage: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .accounts: return "person.2.fill"
        case .settings: return "gearshape.fill"
        }
    }
}

struct RootTabView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label(PhoneRootTab.overview.rawValue, systemImage: PhoneRootTab.overview.systemImage) }
            AccountsView()
                .tabItem { Label(PhoneRootTab.accounts.rawValue, systemImage: PhoneRootTab.accounts.systemImage) }
            PhoneSettingsView()
                .tabItem { Label(PhoneRootTab.settings.rawValue, systemImage: PhoneRootTab.settings.systemImage) }
        }
    }
}
