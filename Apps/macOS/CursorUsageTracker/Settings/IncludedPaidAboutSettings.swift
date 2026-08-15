import SwiftUI
import AppKit
import AIMeterCore

struct IncludedUsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme
    @State private var splitHeight: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsAccountPicker()
                if let snapshot = store.snapshot {
                    subscriptionHero(snapshot)
                    pools(snapshot)
                    if !snapshot.cycleHistory.isEmpty {
                        cycleHistoryPanel(snapshot)
                    }
                    if store.preferences.popover.burnRateEstimate, let pace = snapshot.pace() {
                        Label(pace.caption, systemImage: pace.systemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(alignment: .top, spacing: 10) {
                        models(snapshot)
                            .reportMatchedHeight()
                            .frame(maxWidth: .infinity, alignment: .top)
                            .fillMatchedHeight(splitHeight)
                        activityColumn
                            .reportMatchedHeight()
                            .frame(width: 320, alignment: .top)
                            .fillMatchedHeight(splitHeight)
                    }
                    .onPreferenceChange(MatchedHeightKey.self) { splitHeight = $0 }
                } else {
                    ContentUnavailableView(
                        "No usage yet",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Sign in and refresh to see included usage.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { store.refreshLocalActivity() }
    }

    private func subscriptionHero(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(title: "Subscription", systemImage: "crown", subtitle: nil, compact: true) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(snapshot.planDisplayName)
                            .font(.headline)
                        if let status = snapshot.subscriptionStatus {
                            Text(status)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(theme.ok.opacity(0.15)))
                                .foregroundStyle(theme.ok)
                        }
                    }
                    if let start = snapshot.billingCycleStart, let end = snapshot.billingCycleEnd {
                        Text("\(start.formatted(date: .abbreviated, time: .omitted)) → \(end.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let used = snapshot.planUsedCents {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(MenuBarFormatter.usd(used))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                        Text("period total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let days = snapshot.daysRemainingInCycle {
                    Text("\(days)d left")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(theme.total.opacity(0.15)))
                        .foregroundStyle(theme.total)
                }
            }
        }
    }

    private func pools(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(
            title: "Included pools",
            systemImage: "chart.bar.fill",
            subtitle: "Live percentages from Cursor.",
            compact: true
        ) {
            HStack(alignment: .top, spacing: 8) {
                if let p = snapshot.cursorModelsPercentUsed {
                    IncludedPoolCard(
                        title: "Cursor Models",
                        systemImage: "sparkles",
                        percent: p,
                        caption: "First-party",
                        accent: theme.cursorModels,
                        compact: true
                    )
                }
                if let p = snapshot.otherModelsPercentUsed {
                    IncludedPoolCard(
                        title: "Other Models",
                        systemImage: "cpu",
                        percent: p,
                        caption: "API / third-party",
                        accent: theme.otherModels,
                        compact: true
                    )
                }
                if let p = snapshot.totalPercentUsed {
                    IncludedPoolCard(
                        title: "Total included",
                        systemImage: "chart.pie.fill",
                        percent: p,
                        caption: "Overall pool",
                        accent: theme.total,
                        compact: true
                    )
                }
            }

            if let bonus = snapshot.bonusCents, bonus > 0 {
                HStack(spacing: 8) {
                    Label("Bonus credit", systemImage: "gift.fill")
                        .font(.caption)
                    Spacer()
                    Text(MenuBarFormatter.usd(bonus))
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(theme.spend)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(theme.spend.opacity(0.08)))
            }
        }
    }

    private func cycleHistoryPanel(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(
            title: "Spend by cycle",
            systemImage: "chart.bar.fill",
            subtitle: snapshot.cycleComparisonCaption ?? "Model spend for each billing window.",
            compact: true
        ) {
            CycleSpendChart(cycles: snapshot.cycleHistory, height: 120)
            HStack {
                Text("This cycle is still in progress. Invoices stay on Cursor’s dashboard.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button {
                    UsageExportPanel.present(snapshot: snapshot)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var activityColumn: some View {
        agentsPanel
            .frame(maxHeight: .infinity, alignment: .top)
    }

    private var agentsPanel: some View {
        let mac = store.thisMac
        let account = store.activeAccount
        return SettingsPanel(
            title: "Agents",
            systemImage: "cpu",
            subtitle: "This Mac, CLI, and cloud — same family, different runtimes.",
            compact: true,
            fillsHeight: true
        ) {
            VStack(alignment: .leading, spacing: 12) {
                agentGroup(title: "This Mac") {
                    thisMacRow(
                        text: mac.summaryLine,
                        badge: mac.windowCount > 0 ? "\(mac.windowCount)" : nil,
                        tint: theme.cursorModels
                    )
                    chatRows(store.localComposers, empty: "No recent editor chats.")
                }

                if mac.showsCLIRow || !store.localCLISessions.isEmpty {
                    Divider().opacity(0.5)
                    agentGroup(title: "CLI") {
                        if mac.showsCLIRow {
                            thisMacRow(
                                text: mac.cliSummaryLine,
                                badge: mac.cliProcessCount > 0 ? "\(mac.cliProcessCount)" : nil,
                                tint: theme.otherModels
                            )
                        }
                        chatRows(store.localCLISessions, empty: "No recent CLI sessions.")
                    }
                }

                Divider().opacity(0.5)
                agentGroup(title: "Cloud") {
                    cloudAgentsBody(account)
                }

                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func agentGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    @ViewBuilder
    private func chatRows(_ rows: [LocalComposerSummary], empty: String) -> some View {
        if rows.isEmpty {
            Text(empty)
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Text(row.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if let folder = row.projectFolder {
                        Text(folder)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 6)
                    Text(row.activityModeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(row.updatedAt.map { MenuBarFormatter.relative($0) } ?? "—")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, alignment: .trailing)
                }
            }
        }
    }

    private func thisMacRow(text: String, badge: String?, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.caption)
            Spacer(minLength: 0)
            if let badge {
                Text(badge)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(tint.opacity(0.18)))
                    .foregroundStyle(tint)
            }
        }
    }

    @ViewBuilder
    private func cloudAgentsBody(_ account: AccountRuntime?) -> some View {
        if account?.hasCloudAPIKey != true {
            Text("Paste a user API key in Authentication to list bc-* cloud runs.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else if let error = account?.cloudAgentsError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.orange)
        } else if let agents = account?.cloudAgents, !agents.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(agents.prefix(8)) { agent in
                    Button {
                        if let url = agent.url {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(agent.isRunning ? theme.ok : Color.secondary.opacity(0.4))
                                .frame(width: 7, height: 7)
                            Text(agent.name)
                                .font(.caption)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Text(agent.displayStatus.lowercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            Text("No active cloud agents.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func models(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(title: "Models this period", systemImage: "list.bullet.rectangle", subtitle: nil, compact: true, fillsHeight: true) {
            if snapshot.modelBreakdown.isEmpty {
                Text("No model breakdown yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 10, verticalSpacing: 0) {
                    ForEach(Array(snapshot.modelBreakdown.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Divider().gridCellUnsizedAxes(.horizontal)
                        }
                        modelRow(
                            name: row.model,
                            tokens: MenuBarFormatter.tokenCaption(row),
                            amount: MenuBarFormatter.usd(row.totalCents),
                            emphasize: false
                        )
                    }
                    Divider()
                        .padding(.vertical, 4)
                        .gridCellUnsizedAxes(.horizontal)
                    modelRow(
                        name: "Total",
                        tokens: MenuBarFormatter.tokenCaption(
                            input: snapshot.totalInputTokens,
                            output: snapshot.totalOutputTokens
                        ),
                        amount: snapshot.totalModelCostCents.map { MenuBarFormatter.usd($0) } ?? "—",
                        emphasize: true
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func modelRow(name: String, tokens: String?, amount: String, emphasize: Bool) -> some View {
        GridRow {
            Group {
                if emphasize {
                    Color.clear.frame(width: 14, height: 1)
                } else {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.otherModels.opacity(0.7))
                }
            }
            .frame(width: 14)

            Text(name)
                .font(emphasize ? .caption.weight(.semibold) : .caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)

            Text(tokens ?? " ")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)

            Text(amount)
                .font(emphasize ? .caption.monospacedDigit().weight(.bold) : .caption.monospacedDigit())
                .gridColumnAlignment(.trailing)
        }
        .padding(.vertical, 4)
    }
}

private struct IncludedPoolCard: View {
    let title: String
    let systemImage: String
    let percent: Double
    let caption: String
    let accent: Color
    var compact: Bool = false
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 8) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(compact ? .caption : .body)
                Text(title)
                    .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text("\(Int(percent.rounded()))%")
                    .font(compact ? .subheadline.monospacedDigit().weight(.bold) : .title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(theme.color(forPool: title, percent: percent))
            }
            UsageProgressBar(
                percent: percent,
                tint: theme.color(forPool: title, percent: percent),
                pattern: .forPool(title)
            )
                .frame(height: compact ? 6 : 8)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(compact ? 8 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .fill(accent.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .strokeBorder(accent.opacity(0.35), lineWidth: 1)
        )
    }
}

struct SettingsAccountPicker: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        if store.accounts.count > 1 {
            SettingsPanel(
                title: "Account",
                systemImage: "person.crop.circle",
                subtitle: "Numbers on this page are for the selected account.",
                compact: true
            ) {
                Picker("Account", selection: Binding(
                    get: { store.activeAccountID ?? store.connections.first?.id ?? UUID() },
                    set: { store.setActive(id: $0) }
                )) {
                    ForEach(store.accounts) { item in
                        Text(item.connection.displayLabel).tag(item.id)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct PaidUsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                SettingsAccountPicker()
                if let snapshot = store.snapshot {
                    account(snapshot)
                    status(snapshot)
                    meters(snapshot)
                } else {
                    ContentUnavailableView(
                        "No paid usage data",
                        systemImage: "creditcard",
                        description: Text("Sign in and refresh to see on-demand status.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func account(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(
            title: "Account",
            systemImage: "person.crop.circle",
            subtitle: snapshot.isYearlyPlan ? "Yearly plan" : "Monthly plan",
            compact: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(snapshot.planDisplayName)
                        .font(.headline)
                    if let status = snapshot.subscriptionStatus {
                        Text(status)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Capsule().fill((snapshot.hasBillingAlert ? theme.danger : theme.ok).opacity(0.15)))
                            .foregroundStyle(snapshot.hasBillingAlert ? theme.danger : theme.ok)
                    }
                    Spacer(minLength: 0)
                }

                if snapshot.lastPaymentFailed {
                    Label("Last payment failed — update billing on Cursor’s site.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let date = snapshot.pendingCancellationDate {
                    Label(
                        "Cancels \(date.formatted(date: .abbreviated, time: .omitted))",
                        systemImage: "calendar.badge.minus"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
                if let balance = snapshot.customerBalanceCents, balance > 0 {
                    Label("Credit \(MenuBarFormatter.usd(balance))", systemImage: "gift")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if snapshot.isOnStudentPlan || snapshot.verifiedStudent || snapshot.studentDiscountApplied {
                    Label("Student pricing", systemImage: "graduationcap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if snapshot.isTeamMember {
                    Label("Team member", systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                CursorBillingLinks()
            }
        }
    }

    private func status(_ snapshot: UsageSnapshot) -> some View {
        let on = snapshot.onDemandEnabled
        return SettingsPanel(
            title: "On-demand",
            systemImage: "creditcard.fill",
            subtitle: on
                ? "Usage beyond included pools, billed at list price."
                : "Off — extra usage is not billed this way.",
            compact: true
        ) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(on ? "Enabled" : "Disabled")
                        .font(.headline)
                    if snapshot.isOnDemandUnlimited {
                        Text("No spend cap on this account.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let used = snapshot.onDemandUsedCents, let limit = snapshot.onDemandLimitCents, limit > 0 {
                        Text("\(MenuBarFormatter.usd(used)) of \(MenuBarFormatter.usd(limit)) billed this period")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let used = snapshot.onDemandUsedCents {
                        Text("\(MenuBarFormatter.usd(used)) billed this period")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(on ? "On" : "Off")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((on ? theme.ok : theme.danger).opacity(0.16)))
                    .foregroundStyle(on ? theme.ok : theme.danger)
            }
        }
    }

    private func meters(_ snapshot: UsageSnapshot) -> some View {
        let used = snapshot.onDemandUsedCents
        let limit = snapshot.onDemandLimitCents
        let percent: Double? = {
            guard let used, let limit, limit > 0 else { return nil }
            return min(100, Double(used) / Double(limit) * 100)
        }()

        return SettingsPanel(
            title: "This period",
            systemImage: "dollarsign.circle.fill",
            subtitle: "Billable on-demand vs the cap Cursor reports.",
            compact: true
        ) {
            HStack(alignment: .top, spacing: 8) {
                PaidStatCard(
                    title: "Billable usage",
                    systemImage: "creditcard",
                    value: used.map(MenuBarFormatter.usd) ?? "—",
                    caption: snapshot.onDemandEnabled ? "Beyond included pools" : "None while off",
                    accent: theme.spend,
                    percent: percent
                )
                PaidStatCard(
                    title: "Usage limit",
                    systemImage: "hand.raised.fill",
                    value: limitLabel(snapshot),
                    caption: limitCaption(snapshot, percent: percent),
                    accent: snapshot.onDemandEnabled ? theme.ok : theme.danger,
                    percent: snapshot.isOnDemandUnlimited ? nil : percent
                )
                if let planUsed = snapshot.planUsedCents, let planLimit = snapshot.planLimitCents {
                    PaidStatCard(
                        title: "Included plan",
                        systemImage: "dollarsign.circle",
                        value: "\(MenuBarFormatter.usd(planUsed))",
                        caption: "of \(MenuBarFormatter.usd(planLimit)) base",
                        accent: theme.total,
                        percent: planLimit > 0 ? min(100, Double(planUsed) / Double(planLimit) * 100) : nil
                    )
                }
            }
        }
    }

    private func limitLabel(_ snapshot: UsageSnapshot) -> String {
        if snapshot.isOnDemandUnlimited { return "Unlimited" }
        if let limit = snapshot.onDemandLimitCents { return MenuBarFormatter.usd(limit) }
        return snapshot.onDemandEnabled ? "—" : "$0"
    }

    private func limitCaption(_ snapshot: UsageSnapshot, percent: Double?) -> String {
        if snapshot.isOnDemandUnlimited { return "No cap" }
        if let percent {
            return "\(Int(percent.rounded()))% of cap"
        }
        if !snapshot.onDemandEnabled { return "On-demand off" }
        return "Cap from Cursor"
    }
}

private struct PaidStatCard: View {
    let title: String
    let systemImage: String
    let value: String
    let caption: String
    let accent: Color
    var percent: Double? = nil
    @Environment(\.appTheme) private var theme
    @Environment(\.appHighContrast) private var highContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let percent {
                UsageProgressBar(percent: percent, tint: accent, pattern: .dashes)
                    .frame(height: 6)
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(highContrast ? 0.22 : 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(accent.opacity(highContrast ? 0.55 : 0.35), lineWidth: 1)
        )
    }
}

struct AboutSettingsView: View {
    @Environment(\.appTheme) private var theme
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.8"
    }

    @State private var installMessage: String?
    @State private var installSucceeded = false
    @State private var heroTextHeight: CGFloat = 72
    @State private var aboutSplitHeight: CGFloat = 0

    private var isRunningFromApplications: Bool {
        AppInstall.isRunningFromApplications
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                hero

                HStack(alignment: .top, spacing: 10) {
                    SettingsPanel(
                        title: "What it tracks",
                        systemImage: "chart.bar.fill",
                        subtitle: "Personal Pro / Pro+ / Ultra.",
                        compact: true,
                        fillsHeight: true
                    ) {
                        VStack(alignment: .leading, spacing: 10) {
                            aboutBullet("sparkles", "Cursor Models included pool")
                            aboutBullet("cpu", "Other Models included pool")
                            aboutBullet("creditcard", "On-demand, limits, and spend")
                            aboutBullet("bell.badge", "Menu bar warnings + notifications")
                        }
                    }
                    .reportMatchedHeight()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .fillMatchedHeight(aboutSplitHeight)

                    SettingsPanel(
                        title: "Desktop widget",
                        systemImage: "rectangle.on.rectangle",
                        subtitle: "Gallery presets for Cursor, Other, Total, On-demand, and Rotate.",
                        compact: true,
                        fillsHeight: true
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Xcode Run copies live in DerivedData, so Edit Widgets search stays empty until the app is installed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if isRunningFromApplications {
                                Label("Installed in Applications — search “AI Meter”.", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Button {
                                    do {
                                        let dest = try AppInstall.copyRunningAppToApplications()
                                        installSucceeded = true
                                        installMessage = "Copied to \(dest.path). Keep this Settings window. Then quit the Xcode copy and open the Applications app."
                                    } catch {
                                        installSucceeded = false
                                        installMessage = "Couldn’t install: \(error.localizedDescription)"
                                    }
                                    AppActivation.scheduleSettingsFocus()
                                } label: {
                                    Label("Install to Applications", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }

                            if installSucceeded, !isRunningFromApplications {
                                HStack(spacing: 8) {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([AppInstall.installedAppURL])
                                        AppActivation.scheduleSettingsFocus()
                                    }
                                    .controlSize(.small)
                                    Button("Quit this copy & open installed app") {
                                        AppInstall.launchInstalledAndTerminate()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }

                            aboutBullet("1.circle", "Install (button above) — does not launch a second copy")
                            aboutBullet("2.circle", "Quit this Xcode build, then open Applications ▸ AI Meter")
                            aboutBullet("3.circle", "Right-click desktop → Edit Widgets → AI Meter presets. Re-add after this update.")

                            if let installMessage {
                                Text(installMessage)
                                    .font(.caption2)
                                    .foregroundStyle(installSucceeded ? Color.secondary : Color.orange)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .reportMatchedHeight()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .fillMatchedHeight(aboutSplitHeight)
                }
                .onPreferenceChange(MatchedHeightKey.self) { aboutSplitHeight = $0 }

                SettingsPanel(
                    title: "Unofficial & local-first",
                    systemImage: "lock.shield",
                    subtitle: nil,
                    compact: true
                ) {
                    Text("Session tokens stay in Keychain on this Mac. Widgets only see a sanitized usage snapshot — never credentials. Cursor’s personal APIs can change; re-auth from Authentication if usage stops updating.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link(destination: AppAbout.dashboardURL) {
                        Label("Cursor dashboard", systemImage: "globe")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            AppLogo(size: heroTextHeight)
            VStack(alignment: .leading, spacing: 4) {
                Text(AppAbout.productLegalName)
                    .font(.title2.weight(.bold))
                Text("Menu bar meter for Cursor, Claude, and Codex — unofficial, local-first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Text("v\(version)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(theme.cursorModels.opacity(0.15)))
                        .foregroundStyle(theme.cursorModels)
                    Text("macOS 14+")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(AppAbout.organization)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppAbout.copyrightLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("License: \(AppAbout.licenseName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: HeroTextHeightKey.self, value: geo.size.height)
                }
            )
            .onPreferenceChange(HeroTextHeightKey.self) { newValue in
                let next = max(newValue, 64)
                if abs(next - heroTextHeight) > 0.5 {
                    heroTextHeight = next
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func aboutBullet(_ systemImage: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundStyle(theme.tint)
                .frame(width: 16, alignment: .center)
                .padding(.top, 1)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HeroTextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 88
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
