import SwiftUI
import CursorUsageCore
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var notificationPermissionHint: String?

    private let intervals = [1, 2, 5, 15, 30]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanel(
                    title: "App behavior",
                    systemImage: "bolt.horizontal.circle",
                    subtitle: "Launch, sync cadence, and alerts."
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

                        warningAndNotifications
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

                        VStack(alignment: .leading, spacing: 10) {
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

                        VStack(alignment: .leading, spacing: 10) {
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

    private var warningAndNotifications: some View {
        let threshold = store.preferences.warningThresholdPercent
        let warnColor = UsageAppearance.poolColor(percent: threshold)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text("Menu bar warning")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(threshold))%")
                        .font(.subheadline.monospacedDigit().weight(.bold))
                        .foregroundStyle(warnColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(warnColor.opacity(0.15)))
                }

                Slider(value: thresholdBinding, in: 50...100, step: 1)
                    .tint(warnColor)

                Text("Shows a red dot on the menu bar icon when Cursor Models, Other Models, or Total included hits this level.")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(warnColor.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(warnColor.opacity(0.35), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: notificationsBinding) {
                    Label("System notifications", systemImage: "bell.badge.fill")
                        .font(.subheadline.weight(.semibold))
                }

                Text("Get a macOS banner when usage crosses a selected threshold (once per threshold each billing cycle).")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)

                if store.preferences.notificationsEnabled {
                    Text("Notify at")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(DisplayPreferences.presetNotificationThresholds, id: \.self) { value in
                            let selected = store.preferences.notificationThresholds.contains(value)
                            Button {
                                var prefs = store.preferences
                                prefs.toggleNotificationThreshold(value)
                                store.applyPreferences(prefs)
                            } label: {
                                Text("\(Int(value))%")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selected ? UsageAppearance.accentOtherModels : Color.primary.opacity(0.06))
                                    )
                                    .foregroundStyle(selected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let notificationPermissionHint {
                        Text(notificationPermissionHint)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(UsageAppearance.accentOtherModels.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(UsageAppearance.accentOtherModels.opacity(0.25), lineWidth: 1)
            )
        }
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

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.notificationsEnabled },
            set: { value in
                var prefs = store.preferences
                prefs.notificationsEnabled = value
                store.applyPreferences(prefs)
                if value {
                    Task {
                        let ok = await UsageNotificationService.requestAuthorizationIfNeeded()
                        notificationPermissionHint = ok
                            ? nil
                            : "Notifications are blocked — enable them for Cursor Usage Tracker in System Settings → Notifications."
                    }
                }
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
