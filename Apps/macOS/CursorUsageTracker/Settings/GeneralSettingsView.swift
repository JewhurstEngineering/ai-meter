import SwiftUI
import CursorUsageCore
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    private let intervals = [1, 2, 5, 15, 30]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "App behavior",
                    systemImage: "bolt.horizontal.circle",
                    subtitle: "How often we sync and when the menu bar warns you."
                ) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle("Launch at login", isOn: launchAtLoginBinding)
                            Picker("Refresh every", selection: refreshBinding) {
                                ForEach(intervals, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(minutes)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 180, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Warning at \(Int(store.preferences.warningThresholdPercent))%")
                                .font(.subheadline.weight(.medium))
                            Slider(value: thresholdBinding, in: 50...100, step: 1)
                            Text("Red dot on the menu bar icon when any watched pool crosses this line.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HStack(alignment: .top, spacing: 16) {
                    SettingsPanel(
                        title: "Menu bar",
                        systemImage: "menubar.rectangle",
                        subtitle: "Compact glance strip in the system menu bar."
                    ) {
                        Toggle("Show title text in menu bar", isOn: showMenuBarBinding)
                        Picker("Density", selection: formatBinding) {
                            Text("Compact").tag(DisplayPreferences.MenuBarFormat.compact)
                            Text("Detailed").tag(DisplayPreferences.MenuBarFormat.detailed)
                        }
                        .pickerStyle(.segmented)

                        Divider().padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            MetricToggleRow(title: "Cursor Models %", systemImage: "sparkles", isOn: menuToggle(\.cursorModelsPercent))
                            MetricToggleRow(title: "Other Models %", systemImage: "cpu", isOn: menuToggle(\.otherModelsPercent))
                            MetricToggleRow(title: "Total included %", systemImage: "chart.pie", isOn: menuToggle(\.totalPercent))
                            MetricToggleRow(title: "Subscription $", systemImage: "dollarsign.circle", isOn: menuToggle(\.planSpend))
                            MetricToggleRow(title: "Bonus", systemImage: "gift", isOn: menuToggle(\.bonus))
                            MetricToggleRow(title: "On-demand", systemImage: "creditcard", isOn: menuToggle(\.onDemand))
                            MetricToggleRow(title: "Days remaining", systemImage: "calendar", isOn: menuToggle(\.daysRemaining))
                        }
                    }

                    SettingsPanel(
                        title: "Popover",
                        systemImage: "rectangle.portrait.on.rectangle.portrait",
                        subtitle: "What appears when you click the menu bar item."
                    ) {
                        Text("Detail panel")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 8) {
                            MetricToggleRow(title: "Cursor Models %", systemImage: "sparkles", isOn: popoverToggle(\.cursorModelsPercent))
                            MetricToggleRow(title: "Other Models %", systemImage: "cpu", isOn: popoverToggle(\.otherModelsPercent))
                            MetricToggleRow(title: "Total included %", systemImage: "chart.pie", isOn: popoverToggle(\.totalPercent))
                            MetricToggleRow(title: "Plan spend", systemImage: "dollarsign.circle", isOn: popoverToggle(\.planSpend))
                            MetricToggleRow(title: "Bonus", systemImage: "gift", isOn: popoverToggle(\.bonus))
                            MetricToggleRow(title: "On-demand", systemImage: "creditcard", isOn: popoverToggle(\.onDemand))
                            MetricToggleRow(title: "Days remaining", systemImage: "calendar", isOn: popoverToggle(\.daysRemaining))
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
                } catch {}
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
