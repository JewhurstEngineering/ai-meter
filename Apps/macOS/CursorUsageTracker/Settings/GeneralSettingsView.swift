import SwiftUI
import CursorUsageCore
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    private let intervals = [1, 2, 5, 15, 30]

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
            }
            Section("Refresh") {
                Picker("Interval", selection: refreshBinding) {
                    ForEach(intervals, id: \.self) { minutes in
                        Text("\(minutes) minute(s)").tag(minutes)
                    }
                }
            }
            Section("Warnings") {
                VStack(alignment: .leading) {
                    Slider(value: thresholdBinding, in: 50...100, step: 1)
                    Text("Show warning dot when usage exceeds \(Int(store.preferences.warningThresholdPercent))% of a watched pool.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Menu Bar") {
                Toggle("Show in Menu Bar", isOn: showMenuBarBinding)
                Picker("Format", selection: formatBinding) {
                    Text("Compact").tag(DisplayPreferences.MenuBarFormat.compact)
                    Text("Detailed").tag(DisplayPreferences.MenuBarFormat.detailed)
                }
                .pickerStyle(.segmented)
                Toggle("Cursor Models %", isOn: menuToggle(\.cursorModelsPercent))
                Toggle("Other Models %", isOn: menuToggle(\.otherModelsPercent))
                Toggle("Total included %", isOn: menuToggle(\.totalPercent))
                Toggle("Subscription usage ($)", isOn: menuToggle(\.planSpend))
                Toggle("Bonus usage details", isOn: menuToggle(\.bonus))
                Toggle("On-demand / billable", isOn: menuToggle(\.onDemand))
                Toggle("Days remaining", isOn: menuToggle(\.daysRemaining))
            }
            Section("Popover") {
                Toggle("Cursor Models %", isOn: popoverToggle(\.cursorModelsPercent))
                Toggle("Other Models %", isOn: popoverToggle(\.otherModelsPercent))
                Toggle("Total included %", isOn: popoverToggle(\.totalPercent))
                Toggle("Plan spend", isOn: popoverToggle(\.planSpend))
                Toggle("Bonus", isOn: popoverToggle(\.bonus))
                Toggle("On-demand", isOn: popoverToggle(\.onDemand))
                Toggle("Days remaining", isOn: popoverToggle(\.daysRemaining))
            }
        }
        .formStyle(.grouped)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.launchAtLogin },
            set: { newValue in
                var prefs = store.preferences
                prefs.launchAtLogin = newValue
                store.applyPreferences(prefs)
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    // Best-effort; preference still saved.
                }
            }
        )
    }

    private var refreshBinding: Binding<Int> {
        Binding(
            get: { store.preferences.refreshIntervalMinutes },
            set: { value in
                var prefs = store.preferences
                prefs.refreshIntervalMinutes = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { store.preferences.warningThresholdPercent },
            set: { value in
                var prefs = store.preferences
                prefs.warningThresholdPercent = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var showMenuBarBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.showInMenuBar },
            set: { value in
                var prefs = store.preferences
                prefs.showInMenuBar = value
                store.applyPreferences(prefs)
            }
        )
    }

    private var formatBinding: Binding<DisplayPreferences.MenuBarFormat> {
        Binding(
            get: { store.preferences.menuBarFormat },
            set: { value in
                var prefs = store.preferences
                prefs.menuBarFormat = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func menuToggle(_ keyPath: WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences.menuBar[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.menuBar[keyPath: keyPath] = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func popoverToggle(_ keyPath: WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.preferences.popover[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.popover[keyPath: keyPath] = value
                store.applyPreferences(prefs)
            }
        )
    }
}
