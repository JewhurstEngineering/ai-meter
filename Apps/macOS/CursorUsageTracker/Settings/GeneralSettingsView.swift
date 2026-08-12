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
                    title: "Startup & sync",
                    systemImage: "bolt.horizontal.circle",
                    subtitle: "When the app launches and how often it refreshes."
                ) {
                    HStack(spacing: 20) {
                        Toggle("Launch at login", isOn: launchAtLoginBinding)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 8) {
                            Text("Refresh every")
                                .foregroundStyle(.secondary)
                            Picker("Refresh every", selection: refreshBinding) {
                                ForEach(intervals, id: \.self) { minutes in
                                    Text("\(minutes) min").tag(minutes)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 100, alignment: .trailing)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                // Tallest card wins; both stretch so bottoms stay aligned.
                HStack(alignment: .top, spacing: 14) {
                    menuBarWarningCard
                    systemNotificationsCard
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var menuBarWarningCard: some View {
        let surface = Color(red: 0.93, green: 0.96, blue: 0.98)
        let border = Color(red: 0.55, green: 0.68, blue: 0.78)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "menubar.rectangle")
                    .foregroundStyle(.tint)
                Text("Menu bar warning")
                    .font(.headline)
                Spacer(minLength: 0)
            }

            Text("Red dot when any enabled channel hits its own level.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            warningChannelRow(
                title: "Cursor Models",
                systemImage: "sparkles",
                tint: UsageAppearance.accentCursorModels,
                value: warningBinding(\.cursorModelsPercent)
            )
            warningChannelRow(
                title: "Other Models",
                systemImage: "cpu",
                tint: UsageAppearance.accentOtherModels,
                value: warningBinding(\.otherModelsPercent)
            )
            warningChannelRow(
                title: "On-demand & limits",
                systemImage: "creditcard",
                tint: UsageAppearance.accentSpend,
                value: warningBinding(\.onDemandAndLimitsPercent)
            )

            Label(
                "Limits = plan spend vs included + on-demand vs its cap.",
                systemImage: "eye"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(border.opacity(0.55), lineWidth: 1)
        )
    }

    private func warningChannelRow(
        title: String,
        systemImage: String,
        tint: Color,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text("\(Int(value.wrappedValue))%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
            }
            Slider(value: value, in: 50...100, step: 1)
                .controlSize(.mini)
                .tint(.red)
        }
    }

    private var systemNotificationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(UsageAppearance.accentOtherModels)
                Text("System notifications")
                    .font(.headline)
                Spacer(minLength: 0)
                Toggle("", isOn: notificationsBinding)
                    .labelsHidden()
                    .toggleStyle(ReliableSwitchToggleStyle())
            }

            Text("Banner once per threshold each billing cycle.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if store.preferences.notificationsEnabled {
                Text("Notify at")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                // Single non-wrapping row — compact chips.
                HStack(spacing: 4) {
                    ForEach(DisplayPreferences.presetNotificationThresholds, id: \.self) { value in
                        let selected = store.preferences.notificationThresholds.contains(value)
                        Button {
                            var prefs = store.preferences
                            prefs.toggleNotificationThreshold(value)
                            store.applyPreferences(prefs)
                        } label: {
                            Text("\(Int(value))")
                                .font(.caption2.weight(.bold))
                                .monospacedDigit()
                                .frame(minWidth: 28)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(selected ? UsageAppearance.accentOtherModels : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(selected ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                        .help("\(Int(value))%")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Include in alert")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Pool percent used", isOn: contentBinding(\.includePoolPercent))
                    Toggle("Plan name", isOn: contentBinding(\.includePlanName))
                    Toggle("Included spend ($)", isOn: contentBinding(\.includeSpend))
                    Toggle("Days remaining", isOn: contentBinding(\.includeDaysRemaining))
                    Toggle("Play sound", isOn: contentBinding(\.playSound))
                    Toggle("Session expired / signed out by Cursor", isOn: sessionExpiredNotifyBinding)
                }
                .toggleStyle(.checkbox)
                .font(.caption)

                Text("Session alerts fire once until you sign in again. Manual Sign out does not notify.")
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
                Text("Turn on to choose thresholds and alert contents.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(UsageAppearance.accentOtherModels.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(UsageAppearance.accentOtherModels.opacity(0.25), lineWidth: 1)
        )
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
                prefs.menuBarWarnings = .migrated(fromLegacy: value)
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
                // Keep legacy single field as the lowest channel for older readers.
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
