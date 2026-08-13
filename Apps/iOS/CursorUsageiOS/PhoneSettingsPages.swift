import SwiftUI
import CursorUsageCore

// MARK: - General + alerts

struct PhoneGeneralSettings: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme
    @State private var notificationHint: String?

    private let intervals = [1, 2, 5, 15, 30]
    private var onDemandUnlimited: Bool { store.snapshot?.isOnDemandUnlimited == true }

    var body: some View {
        Form {
            Section {
                Picker("Refresh every", selection: refreshBinding) {
                    ForEach(intervals, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
            } header: {
                Text("Sync")
            } footer: {
                Text("iPhone cannot poll in the background as often as the Mac menu bar. Open the app or pull to refresh. Widgets read the last snapshot.")
            }

            Section {
                warningSlider("Cursor Models", tint: theme.cursorModels, percent: warningBinding(\.cursorModelsPercent))
                warningSlider("Other Models", tint: theme.otherModels, percent: warningBinding(\.otherModelsPercent))
                if onDemandUnlimited {
                    Picker("On-demand spend alert", selection: unlimitedSpendBinding) {
                        ForEach(DisplayPreferences.MenuBarWarningThresholds.unlimitedSpendPresetsCents, id: \.self) { cents in
                            Text(MenuBarFormatter.usd(cents)).tag(cents)
                        }
                    }
                } else {
                    warningSlider("On-demand & limits", tint: theme.spend, percent: warningBinding(\.onDemandAndLimitsPercent))
                }
                warningSlider("Total included", tint: theme.total, percent: warningBinding(\.totalIncludedPercent))
            } header: {
                Text("Alert levels")
            } footer: {
                Text(onDemandUnlimited
                     ? "On-demand is unlimited — alert at the spend amount you set. Same levels as the Mac menu bar."
                     : "Same warning levels as the Mac menu bar. Notifications fire once per channel per billing cycle.")
            }

            Section {
                Toggle("Usage alerts", isOn: notificationsBinding)
                if let notificationHint {
                    Text(notificationHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if store.preferences.notificationsEnabled {
                    Toggle("Cursor Models", isOn: channelBinding(\.cursorModels))
                    Toggle("Other Models", isOn: channelBinding(\.otherModels))
                    Toggle("On-demand & limits", isOn: channelBinding(\.onDemandAndLimits))
                    Toggle("Total included", isOn: channelBinding(\.totalIncluded))
                }
            } header: {
                Text("Notify for")
            }

            if store.preferences.notificationsEnabled {
                Section("Include in alert") {
                    Toggle("Pool / amount", isOn: contentBinding(\.includePoolPercent))
                    Toggle("Plan name", isOn: contentBinding(\.includePlanName))
                    Toggle("Spend ($)", isOn: contentBinding(\.includeSpend))
                    Toggle("Days left", isOn: contentBinding(\.includeDaysRemaining))
                    Toggle("Sound", isOn: contentBinding(\.playSound))
                    Toggle("Session expired", isOn: sessionExpiredBinding)
                }
            }
        }
        .navigationTitle("General & alerts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func warningSlider(_ title: String, tint: Color, percent: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(percent.wrappedValue))%")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(tint)
            }
            Slider(value: percent, in: 1...100, step: 1)
                .tint(tint)
        }
    }

    private var refreshBinding: Binding<Int> {
        Binding(
            get: { store.preferences.refreshIntervalMinutes },
            set: { value in store.updatePreferences { $0.refreshIntervalMinutes = value } }
        )
    }

    private var unlimitedSpendBinding: Binding<Int> {
        Binding(
            get: { store.preferences.menuBarWarnings.onDemandUnlimitedAlertCents },
            set: { value in
                store.updatePreferences {
                    $0.menuBarWarnings.onDemandUnlimitedAlertCents =
                        DisplayPreferences.MenuBarWarningThresholds.clampCents(value)
                }
            }
        )
    }

    private func warningBinding(
        _ keyPath: WritableKeyPath<DisplayPreferences.MenuBarWarningThresholds, Double>
    ) -> Binding<Double> {
        Binding(
            get: { store.preferences.menuBarWarnings[keyPath: keyPath] },
            set: { value in
                store.updatePreferences { prefs in
                    prefs.menuBarWarnings[keyPath: keyPath] = DisplayPreferences.MenuBarWarningThresholds.clamp(value)
                    let w = prefs.menuBarWarnings
                    prefs.warningThresholdPercent = min(
                        w.cursorModelsPercent,
                        w.otherModelsPercent,
                        w.onDemandAndLimitsPercent,
                        w.totalIncludedPercent
                    )
                }
            }
        )
    }

    private func channelBinding(
        _ keyPath: WritableKeyPath<DisplayPreferences.NotificationChannels, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { store.preferences.notificationChannels[keyPath: keyPath] },
            set: { value in store.updatePreferences { $0.notificationChannels[keyPath: keyPath] = value } }
        )
    }

    private func contentBinding(
        _ keyPath: WritableKeyPath<DisplayPreferences.NotificationContent, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { store.preferences.notificationContent[keyPath: keyPath] },
            set: { value in store.updatePreferences { $0.notificationContent[keyPath: keyPath] = value } }
        )
    }

    private var sessionExpiredBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.notifyOnSessionExpired },
            set: { value in store.updatePreferences { $0.notifyOnSessionExpired = value } }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.notificationsEnabled },
            set: { enabled in
                store.updatePreferences { $0.notificationsEnabled = enabled }
                if enabled {
                    Task {
                        let ok = await UsageNotificationService.requestAuthorizationIfNeeded()
                        notificationHint = ok ? "Alerts allowed." : "Enable notifications in iOS Settings."
                    }
                } else {
                    notificationHint = nil
                }
            }
        )
    }
}

// MARK: - Layout

struct PhoneLayoutSettings: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        Form {
            Section {
                Toggle("Cursor Models %", isOn: popoverBinding(\.cursorModelsPercent))
                Toggle("Other Models %", isOn: popoverBinding(\.otherModelsPercent))
                Toggle("Total included %", isOn: popoverBinding(\.totalPercent))
                Toggle("Subscription $", isOn: popoverBinding(\.planSpend))
                Toggle("Bonus", isOn: popoverBinding(\.bonus))
                Toggle("On-demand", isOn: popoverBinding(\.onDemand))
                Toggle("Days remaining", isOn: popoverBinding(\.daysRemaining))
                Toggle("Models this period", isOn: popoverBinding(\.modelsThisPeriod))
            } header: {
                Text("Overview")
            } footer: {
                Text("Same metric set as the Mac popover. Menu bar density lives on the Mac app.")
            }
        }
        .navigationTitle("Layout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func popoverBinding(
        _ keyPath: WritableKeyPath<DisplayPreferences.SurfaceToggles, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { store.preferences.popover[keyPath: keyPath] },
            set: { value in store.updatePreferences { $0.popover[keyPath: keyPath] = value } }
        )
    }
}

// MARK: - Theme

struct PhoneThemeSettings: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: appearanceBinding) {
                    ForEach(DisplayPreferences.AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Color") {
                ForEach(DisplayPreferences.ColorTheme.allCases) { option in
                    Button {
                        store.updatePreferences { $0.colorTheme = option }
                    } label: {
                        HStack(spacing: 10) {
                            themeSwatches(option)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Text(option.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            if store.preferences.colorTheme == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            if store.preferences.colorTheme == .custom {
                Section("Custom colors") {
                    customPicker("Cursor Models", \.cursorModels)
                    customPicker("Other Models", \.otherModels)
                    customPicker("Total included", \.total)
                    customPicker("Subscription $", \.spend)
                }
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeSwatches(_ option: DisplayPreferences.ColorTheme) -> some View {
        let palette = ThemePalette.resolved(option, scheme: scheme, custom: store.preferences.customThemeColors)
        return HStack(spacing: 3) {
            ForEach(Array(palette.swatches.enumerated()), id: \.offset) { _, color in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 14, height: 22)
            }
        }
    }

    private var appearanceBinding: Binding<DisplayPreferences.AppearanceMode> {
        Binding(
            get: { store.preferences.appearanceMode },
            set: { value in store.updatePreferences { $0.appearanceMode = value } }
        )
    }

    private func customPicker(
        _ title: String,
        _ keyPath: WritableKeyPath<DisplayPreferences.CustomThemeColors, DisplayPreferences.ThemeSwatch>
    ) -> some View {
        ColorPicker(
            title,
            selection: Binding(
                get: { store.preferences.customThemeColors[keyPath: keyPath].color },
                set: { newColor in
                    store.updatePreferences {
                        $0.customThemeColors[keyPath: keyPath] = DisplayPreferences.ThemeSwatch(newColor)
                    }
                }
            ),
            supportsOpacity: false
        )
    }
}

// MARK: - Accessibility

struct PhoneAccessibilitySettings: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        Form {
            Section {
                Picker("Interface size", selection: sizeBinding) {
                    ForEach(DisplayPreferences.InterfaceSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Interface size")
            } footer: {
                Text("Scales type on iPhone. The Mac app magnifies Settings and the popover.")
            }

            Section("Color vision") {
                ForEach(DisplayPreferences.ColorVision.allCases) { option in
                    Button {
                        store.updatePreferences { prefs in
                            prefs.colorVision = option
                            if option != .typical {
                                prefs.distinguishWithoutColor = true
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .foregroundStyle(.primary)
                                Text(option.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.preferences.colorVision == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }

            Section {
                Toggle("Patterns on usage bars", isOn: patternsBinding)
                Toggle("High contrast borders", isOn: contrastBinding)
                previewBar("Cursor Models", 24)
                previewBar("Other Models", 62)
                previewBar("Total included", 91)
            } header: {
                Text("Don’t rely on color alone")
            }
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func previewBar(_ title: String, _ percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(percent))%")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(theme.color(forPool: title, percent: percent))
            }
            UsageProgressBar(
                percent: percent,
                tint: theme.color(forPool: title, percent: percent),
                pattern: .forPool(title)
            )
        }
    }

    private var sizeBinding: Binding<DisplayPreferences.InterfaceSize> {
        Binding(
            get: { store.preferences.interfaceSize },
            set: { value in store.updatePreferences { $0.interfaceSize = value } }
        )
    }

    private var patternsBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.distinguishWithoutColor },
            set: { value in store.updatePreferences { $0.distinguishWithoutColor = value } }
        )
    }

    private var contrastBinding: Binding<Bool> {
        Binding(
            get: { store.preferences.highContrast },
            set: { value in store.updatePreferences { $0.highContrast = value } }
        )
    }
}

// MARK: - Included / paid / about

struct PhoneIncludedSettings: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if let snapshot = store.snapshot {
                List {
                    Section("Subscription") {
                        LabeledContent("Plan", value: snapshot.planDisplayName)
                        if let status = snapshot.subscriptionStatus {
                            LabeledContent("Status", value: status)
                        }
                        if let start = snapshot.billingCycleStart, let end = snapshot.billingCycleEnd {
                            LabeledContent("Cycle") {
                                Text("\(start.formatted(date: .abbreviated, time: .omitted)) → \(end.formatted(date: .abbreviated, time: .omitted))")
                            }
                        }
                        if let days = snapshot.daysRemainingInCycle {
                            LabeledContent("Remaining", value: "\(days)d")
                        }
                    }
                    Section("Included pools") {
                        if let p = snapshot.cursorModelsPercentUsed {
                            pool("Cursor Models", "sparkles", p, theme.cursorModels)
                        }
                        if let p = snapshot.otherModelsPercentUsed {
                            pool("Other Models", "cpu", p, theme.otherModels)
                        }
                        if let p = snapshot.totalPercentUsed {
                            pool("Total included", "chart.pie.fill", p, theme.total)
                        }
                        if let bonus = snapshot.bonusCents, bonus > 0 {
                            LabeledContent("Bonus credit") {
                                Text(MenuBarFormatter.usd(bonus)).monospacedDigit()
                            }
                        }
                    }
                    if !snapshot.modelBreakdown.isEmpty {
                        Section("Models this period") {
                            ForEach(snapshot.modelBreakdown) { row in
                                LabeledContent(row.model) {
                                    Text(MenuBarFormatter.usd(row.totalCents)).monospacedDigit()
                                }
                            }
                            if let total = snapshot.totalModelCostCents {
                                LabeledContent("Total") {
                                    Text(MenuBarFormatter.usd(total))
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No usage yet",
                    systemImage: "chart.bar.doc.horizontal",
                    description: Text("Sign in and refresh to see included usage.")
                )
            }
        }
        .navigationTitle("Included usage")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pool(_ title: String, _ image: String, _ percent: Double, _ accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: image)
                Spacer()
                Text("\(Int(percent.rounded()))%")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(theme.color(forPool: title, percent: percent))
            }
            UsageProgressBar(
                percent: percent,
                tint: theme.color(forPool: title, percent: percent),
                pattern: .forPool(title)
            )
        }
        .padding(.vertical, 4)
    }
}

struct PhonePaidSettings: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        Group {
            if let snapshot = store.snapshot {
                List {
                    Section("On-demand") {
                        LabeledContent("Status") {
                            Text(snapshot.onDemandEnabled ? "Enabled" : "Disabled")
                                .foregroundStyle(snapshot.onDemandEnabled ? theme.ok : theme.danger)
                        }
                        if snapshot.isOnDemandUnlimited {
                            LabeledContent("Limit", value: "Unlimited")
                        } else if let used = snapshot.onDemandUsedCents, let limit = snapshot.onDemandLimitCents, limit > 0 {
                            LabeledContent("Billable") {
                                Text("\(MenuBarFormatter.usd(used)) of \(MenuBarFormatter.usd(limit))")
                                    .monospacedDigit()
                            }
                        } else if let used = snapshot.onDemandUsedCents {
                            LabeledContent("Billable") {
                                Text(MenuBarFormatter.usd(used)).monospacedDigit()
                            }
                        }
                    }
                    if let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                        Section("Included plan") {
                            LabeledContent("Spend") {
                                Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No paid usage data",
                    systemImage: "creditcard",
                    description: Text("Sign in and refresh to see on-demand status.")
                )
            }
        }
        .navigationTitle("Paid usage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhoneAboutSettings: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    AppLogo(size: 64)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                LabeledContent("Version", value: version)
            }
            Section("What it tracks") {
                Label("Cursor Models included pool", systemImage: "sparkles")
                Label("Other Models included pool", systemImage: "cpu")
                Label("On-demand, limits, and spend", systemImage: "creditcard")
                Label("Warnings + notifications", systemImage: "bell.badge")
            }
            Section {
                Text("Personal Cursor Pro / Pro+ / Ultra meter. Team Admin API is parked. Tokens stay in this iPhone’s Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
