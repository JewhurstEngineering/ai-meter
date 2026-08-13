import SwiftUI
import CursorUsageCore

struct PhoneSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var notificationHint: String?

    private let intervals = [1, 2, 5, 15, 30]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Refresh every", selection: refreshBinding) {
                        ForEach(intervals, id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                    Toggle("Usage alerts", isOn: notificationsBinding)
                    if let notificationHint {
                        Text(notificationHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("iPhone cannot poll in the background as often as the Mac menu bar. Open the app or pull to refresh for a fresh reading. Widgets read the last snapshot.")
                }

                Section("Watch") {
                    Text("The paired Apple Watch only receives a sanitized usage snapshot. Session tokens never leave this iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    Text("Personal Cursor Pro / Pro+ / Ultra meter. Team Admin API is parked.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var refreshBinding: Binding<Int> {
        Binding(
            get: { store.preferences.refreshIntervalMinutes },
            set: { minutes in
                var prefs = store.preferences
                prefs.refreshIntervalMinutes = minutes
                store.applyPreferences(prefs)
            }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.notificationsEnabled },
            set: { enabled in
                var prefs = store.preferences
                prefs.notificationsEnabled = enabled
                store.applyPreferences(prefs)
                if enabled {
                    Task {
                        let ok = await UsageNotificationService.requestAuthorizationIfNeeded()
                        notificationHint = ok ? "Alerts allowed." : "Enable notifications in iOS Settings."
                    }
                }
            }
        )
    }
}
