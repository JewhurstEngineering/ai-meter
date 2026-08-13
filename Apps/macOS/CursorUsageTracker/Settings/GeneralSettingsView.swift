import SwiftUI
import CursorUsageCore
import ServiceManagement

struct GeneralSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme
    @State private var notificationPermissionHint: String?

    private let intervals = [1, 2, 5, 15, 30]

    private var onDemandUnlimited: Bool {
        store.snapshot?.isOnDemandUnlimited == true
    }

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
                    subtitle: "Warning triangle in the menu bar when any channel hits its level. Hover the meter or open the popover to see which one.",
                    compact: true
                ) {
                    HStack(alignment: .top, spacing: 8) {
                        warningCard(
                            title: "Cursor Models",
                            systemImage: "sparkles",
                            tint: theme.cursorModels,
                            percent: warningBinding(\.cursorModelsPercent)
                        )
                        warningCard(
                            title: "Other Models",
                            systemImage: "cpu",
                            tint: theme.otherModels,
                            percent: warningBinding(\.otherModelsPercent)
                        )
                        if onDemandUnlimited {
                            unlimitedSpendCard
                        } else {
                            warningCard(
                                title: "On-demand & limits",
                                systemImage: "creditcard",
                                tint: theme.spend,
                                percent: warningBinding(\.onDemandAndLimitsPercent)
                            )
                        }
                    }

                    Text(
                        onDemandUnlimited
                            ? "On-demand is unlimited — menu bar warns at the spend amount you set."
                            : "Limits = plan spend vs included + on-demand vs its cap."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                SettingsPanel(
                    title: "System notifications",
                    systemImage: "bell.badge.fill",
                    subtitle: "Uses each menu-bar warning level above — once per channel per billing cycle.",
                    compact: true
                ) {
                    HStack {
                        Text(store.preferences.notificationsEnabled ? "Enabled" : "Off")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Toggle("", isOn: notificationsBinding)
                            .labelsHidden()
                            .toggleStyle(ReliableSwitchToggleStyle(onColor: theme.otherModels))
                    }

                    if store.preferences.notificationsEnabled {
                        Text("Notify for")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible())],
                            alignment: .leading,
                            spacing: 8
                        ) {
                            channelToggle(
                                "Cursor Models",
                                detail: "\(Int(store.preferences.menuBarWarnings.cursorModelsPercent))%",
                                tint: theme.cursorModels,
                                isOn: channelBinding(\.cursorModels)
                            )
                            channelToggle(
                                "Other Models",
                                detail: "\(Int(store.preferences.menuBarWarnings.otherModelsPercent))%",
                                tint: theme.otherModels,
                                isOn: channelBinding(\.otherModels)
                            )
                            channelToggle(
                                "On-demand & limits",
                                detail: onDemandUnlimited
                                    ? MenuBarFormatter.usd(store.preferences.menuBarWarnings.onDemandUnlimitedAlertCents)
                                    : "\(Int(store.preferences.menuBarWarnings.onDemandAndLimitsPercent))%",
                                tint: theme.spend,
                                isOn: channelBinding(\.onDemandAndLimits)
                            )
                            channelToggle(
                                "Total included",
                                detail: "\(Int(store.preferences.menuBarWarnings.totalIncludedPercent))%",
                                tint: theme.total,
                                isOn: channelBinding(\.totalIncluded)
                            ) {
                                totalThresholdStepper
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Include in alert")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                ],
                                alignment: .leading,
                                spacing: 6
                            ) {
                                Toggle("Pool / amount", isOn: contentBinding(\.includePoolPercent))
                                Toggle("Plan name", isOn: contentBinding(\.includePlanName))
                                Toggle("Spend ($)", isOn: contentBinding(\.includeSpend))
                                Toggle("Days left", isOn: contentBinding(\.includeDaysRemaining))
                                Toggle("Sound", isOn: contentBinding(\.playSound))
                                Toggle("Session expired", isOn: sessionExpiredNotifyBinding)
                            }
                            .toggleStyle(.checkbox)
                            .font(.caption)
                        }

                        Text("Session expired fires once until you sign in again (not on manual Sign out).")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        if let notificationPermissionHint {
                            Text(notificationPermissionHint)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text("Turn on, then pick which channels notify at their warning levels.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var unlimitedSpendCard: some View {
        let cents = store.preferences.menuBarWarnings.onDemandUnlimitedAlertCents
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "creditcard")
                    .font(.caption)
                Text("On-demand spend")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(MenuBarFormatter.usd(cents))
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(theme.spend)
            }
            Text("Unlimited — alert at amount")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Picker("Alert at", selection: unlimitedSpendBinding) {
                ForEach(DisplayPreferences.MenuBarWarningThresholds.unlimitedSpendPresetsCents, id: \.self) { value in
                    Text(MenuBarFormatter.usd(value)).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.spend.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.spend.opacity(0.35), lineWidth: 1)
        )
    }

    private var totalThresholdStepper: some View {
        HStack(spacing: 4) {
            Text("at")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(Int(store.preferences.menuBarWarnings.totalIncludedPercent))%")
                .font(.caption2.monospacedDigit().weight(.bold))
            Stepper(
                "",
                value: warningBinding(\.totalIncludedPercent),
                in: 1...100,
                step: 1
            )
            .labelsHidden()
            .controlSize(.mini)
        }
    }

    private func warningCard(
        title: String,
        systemImage: String,
        tint: Color,
        percent: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(Int(percent.wrappedValue))%")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
            }
            Slider(value: percent, in: 1...100)
                .controlSize(.small)
                .tint(tint)
            Text("1% – 100%")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
    }

    private func channelToggle(
        _ title: String,
        detail: String,
        tint: Color,
        isOn: Binding<Bool>
    ) -> some View {
        channelToggle(title, detail: detail, tint: tint, isOn: isOn) { EmptyView() }
    }

    private func channelToggle<Trailing: View>(
        _ title: String,
        detail: String,
        tint: Color,
        isOn: Binding<Bool>,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 8) {
            Toggle(isOn: isOn) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Text(detail)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(tint)
                }
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
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

    private var unlimitedSpendBinding: Binding<Int> {
        Binding(
            get: { store.preferences.menuBarWarnings.onDemandUnlimitedAlertCents },
            set: { value in
                var prefs = store.preferences
                prefs.menuBarWarnings.onDemandUnlimitedAlertCents =
                    DisplayPreferences.MenuBarWarningThresholds.clampCents(value)
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
                    w.onDemandAndLimitsPercent,
                    w.totalIncludedPercent
                )
                store.applyPreferences(prefs)
            }
        )
    }

    private func channelBinding(
        _ keyPath: WritableKeyPath<DisplayPreferences.NotificationChannels, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { store.preferences.notificationChannels[keyPath: keyPath] },
            set: { value in
                var prefs = store.preferences
                prefs.notificationChannels[keyPath: keyPath] = value
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
