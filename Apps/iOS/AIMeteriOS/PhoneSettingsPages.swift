import SwiftUI
import AIMeterCore

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
                Toggle("Burn-rate pace", isOn: popoverBinding(\.burnRateEstimate))
                Toggle("Spend by cycle", isOn: popoverBinding(\.cycleChart))
                Toggle("Models this period", isOn: popoverBinding(\.modelsThisPeriod))
                Toggle("Cloud", isOn: popoverBinding(\.cloudAgents))
            } header: {
                Text("Overview")
            } footer: {
                Text("Agents on iPhone is Cloud only. This Mac and CLI stay on the Mac app.")
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
                Picker("Text size", selection: textSizeBinding) {
                    ForEach(DisplayPreferences.InterfaceSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Text size")
            } footer: {
                Text("Makes labels larger. Does not zoom the layout. On Mac, Interface size zooms Settings and the popover.")
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

    private var textSizeBinding: Binding<DisplayPreferences.InterfaceSize> {
        Binding(
            get: { store.preferences.textSize },
            set: { value in store.updatePreferences { $0.textSize = value } }
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        PhoneAccountPager { account in
            includedPage(account)
        }
        .navigationTitle("Included usage")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func includedPage(_ account: AccountRuntime?) -> some View {
        if let snapshot = account?.snapshot {
            List {
                accountHeader(account)
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
                    if let pace = snapshot.pace() {
                        Label(pace.caption, systemImage: pace.systemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !snapshot.cycleHistory.isEmpty {
                    Section("Spend by cycle") {
                        CycleSpendChart(cycles: snapshot.cycleHistory, height: 140)
                        if let caption = snapshot.cycleComparisonCaption {
                            Text(caption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Included pools") {
                    if let p = snapshot.cursorModelsPercentUsed {
                        pool("Cursor Models", "sparkles", p)
                    }
                    if let p = snapshot.otherModelsPercentUsed {
                        pool("Other Models", "cpu", p)
                    }
                    if let p = snapshot.totalPercentUsed {
                        pool("Total included", "chart.pie.fill", p)
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
                            VStack(alignment: .leading, spacing: 2) {
                                LabeledContent(row.model) {
                                    Text(MenuBarFormatter.usd(row.totalCents)).monospacedDigit()
                                }
                                if let tokens = MenuBarFormatter.tokenCaption(row) {
                                    Text(tokens)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let total = snapshot.totalModelCostCents {
                            LabeledContent("Total") {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(MenuBarFormatter.usd(total))
                                        .fontWeight(.semibold)
                                        .monospacedDigit()
                                    if let tokens = MenuBarFormatter.tokenCaption(
                                        input: snapshot.totalInputTokens,
                                        output: snapshot.totalOutputTokens
                                    ) {
                                        Text(tokens)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                Section {
                    if let url = try? UsageExport.writeTemporaryCSV(snapshot) {
                        ShareLink(item: url) {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                } footer: {
                    Text("Exports the numbers this app already shows. No tokens or keys.")
                }
            }
        } else {
            List {
                accountHeader(account)
                Section {
                    ContentUnavailableView(
                        "No usage yet",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Sign in and refresh to see included usage.")
                    )
                }
            }
        }
    }

    private func pool(_ title: String, _ image: String, _ percent: Double) -> some View {
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        PhoneAccountPager { account in
            paidPage(account)
        }
        .navigationTitle("Paid usage")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func paidPage(_ account: AccountRuntime?) -> some View {
        if let snapshot = account?.snapshot {
            List {
                accountHeader(account)
                Section("Account") {
                    LabeledContent("Plan", value: snapshot.planDisplayName)
                    if let status = snapshot.subscriptionStatus {
                        LabeledContent("Status", value: status.capitalized)
                    }
                    LabeledContent("Billing", value: snapshot.isYearlyPlan ? "Yearly" : "Monthly")
                    if snapshot.lastPaymentFailed {
                        Label("Last payment failed", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(theme.danger)
                    }
                    if let date = snapshot.pendingCancellationDate {
                        LabeledContent("Cancels") {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    if let balance = snapshot.customerBalanceCents, balance > 0 {
                        LabeledContent("Credit") {
                            Text(MenuBarFormatter.usd(balance)).monospacedDigit()
                        }
                    }
                    if snapshot.isOnStudentPlan || snapshot.verifiedStudent || snapshot.studentDiscountApplied {
                        LabeledContent("Student pricing", value: "On")
                    }
                    if snapshot.isTeamMember {
                        LabeledContent("Team", value: "Member")
                    }
                }
                Section("Billing") {
                    Link(destination: AppAbout.dashboardURL) {
                        Label("Cursor dashboard", systemImage: "globe")
                    }
                    Link(destination: AppAbout.billingURL) {
                        Label("Billing & invoices", systemImage: "doc.text")
                    }
                }
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
            List {
                accountHeader(account)
                Section {
                    ContentUnavailableView(
                        "No paid usage data",
                        systemImage: "creditcard",
                        description: Text("Sign in and refresh to see on-demand status.")
                    )
                }
            }
        }
    }
}

@ViewBuilder
private func accountHeader(_ account: AccountRuntime?) -> some View {
    Section {
        if let label = account?.connection.displayLabel {
            Text(label)
                .font(.subheadline.weight(.medium))
        }
        PhoneAccountSwitcherChrome()
    }
}

struct PhoneAboutSettings: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                AppFullLogo(height: 92, color: true)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 4, trailing: 20))
            }
            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Developer", value: AppAbout.organization)
                LabeledContent("Copyright", value: AppAbout.copyrightLine)
                LabeledContent("License", value: AppAbout.licenseName)
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
                Text(AppAbout.affiliationDisclaimer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Link(destination: AppAbout.dashboardURL) {
                    Label("Cursor dashboard", systemImage: "globe")
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
