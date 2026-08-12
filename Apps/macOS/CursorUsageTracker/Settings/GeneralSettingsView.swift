import SwiftUI
import CursorUsageCore
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var notificationPermissionHint: String?

    private let intervals = [1, 2, 5, 15, 30]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsPanel(
                    title: "Startup & sync",
                    systemImage: "bolt.horizontal.circle",
                    subtitle: "Launch behavior and refresh cadence.",
                    compact: true
                ) {
                    HStack(spacing: 16) {
                        Toggle("Launch at login", isOn: launchAtLoginBinding)
                        Spacer(minLength: 12)
                        Text("Refresh every")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Refresh every", selection: refreshBinding) {
                            ForEach(intervals, id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 96, alignment: .trailing)
                    }
                }

                SettingsPanel(
                    title: "Menu bar warning",
                    systemImage: "menubar.rectangle",
                    subtitle: "Independent red-dot thresholds per channel.",
                    compact: true
                ) {
                    VStack(spacing: 8) {
                        warningRow(
                            "Cursor Models",
                            systemImage: "sparkles",
                            tint: UsageAppearance.accentCursorModels,
                            value: warningBinding(\.cursorModelsPercent)
                        )
                        Divider().opacity(0.5)
                        warningRow(
                            "Other Models",
                            systemImage: "cpu",
                            tint: UsageAppearance.accentOtherModels,
                            value: warningBinding(\.otherModelsPercent)
                        )
                        Divider().opacity(0.5)
                        warningRow(
                            "On-demand & limits",
                            systemImage: "creditcard",
                            tint: UsageAppearance.accentSpend,
                            value: warningBinding(\.onDemandAndLimitsPercent)
                        )
                    }

                    Text("Limits watch plan spend vs included and on-demand vs its cap.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                SettingsPanel(
                    title: "System notifications",
                    systemImage: "bell.badge.fill",
                    subtitle: "Banner once per threshold each billing cycle.",
                    compact: true
                ) {
                    HStack {
                        Text(store.preferences.notificationsEnabled ? "Enabled" : "Off")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(store.preferences.notificationsEnabled ? .primary : .secondary)
                        Spacer()
                        Toggle("", isOn: notificationsBinding)
                            .labelsHidden()
                            .toggleStyle(ReliableSwitchToggleStyle())
                    }

                    if store.preferences.notificationsEnabled {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Notify at")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 5) {
                                ForEach(DisplayPreferences.presetNotificationThresholds, id: \.self) { value in
                                    let selected = store.preferences.notificationThresholds.contains(value)
                                    Button {
                                        var prefs = store.preferences
                                        prefs.toggleNotificationThreshold(value)
                                        store.applyPreferences(prefs)
                                    } label: {
                                        Text("\(Int(value))%")
                                            .font(.caption2.weight(.semibold))
                                            .monospacedDigit()
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(selected ? Color.accentColor : Color.primary.opacity(0.06))
                                            )
                                            .foregroundStyle(selected ? Color.white : Color.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Include in alert")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)

                            LazyVGrid(
                                columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                                alignment: .leading,
                                spacing: 6
                            ) {
                                Toggle("Pool %", isOn: contentBinding(\.includePoolPercent))
                                Toggle("Plan name", isOn: contentBinding(\.includePlanName))
                                Toggle("Spend ($)", isOn: contentBinding(\.includeSpend))
                                Toggle("Days left", isOn: contentBinding(\.includeDaysRemaining))
                                Toggle("Play sound", isOn: contentBinding(\.playSound))
                                Toggle("Session expired", isOn: sessionExpiredNotifyBinding)
                            }
                            .toggleStyle(.checkbox)
                            .font(.caption)
                        }

                        Text("Session expired fires once until you sign in again (not on manual Sign out).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let notificationPermissionHint {
                            Text(notificationPermissionHint)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    } else {
                        Text("Turn on to pick thresholds and alert contents.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func warningRow(
        _ title: String,
        systemImage: String,
        tint: Color,
        value: Binding<Double>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
                .frame(width: 14)
            Text(title)
                .font(.caption.weight(.medium))
                .frame(width: 118, alignment: .leading)
            Slider(value: value, in: 50...100, step: 1)
                .controlSize(.mini)
                .tint(tint)
            Text("\(Int(value.wrappedValue))%")
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
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

    private func warningBinding(
        _ keyPath: WritableKeyPath<DisplayPreferences.MenuBarWarningThresholds, Double>
    ) -> Binding<Double> {
        Binding(
            get: { store.preferences.menuBarWarnings[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.menuBarWarnings[keyPath: keyPath] = DisplayPreferences.MenuBarWarningThresholds.clamp(value)
                let w = prefs.menuBarWarnings
                prefs.warningThresholdPercent = min(
                    w.cursorModelsPercent,
                    w.otherModelsPercent,
                    w.onDemandAndLimitsPercent
                )
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
                            : "Notifications are blocked — enable them in System Settings → Notifications."
                    }
                }
            }
        )
    }

    private var sessionExpiredNotifyBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.notifyOnSessionExpired },
            set: { value in
                var prefs = store.preferences
                prefs.notifyOnSessionExpired = value
                store.applyPreferences(prefs)
            }
        )
    }

    private func contentBinding(
        _ keyPath: WritableKeyPath<DisplayPreferences.NotificationContent, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { store.preferences.notificationContent[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.notificationContent[keyPath: keyPath] = value
                store.applyPreferences(prefs)
            }
        )
    }
}
