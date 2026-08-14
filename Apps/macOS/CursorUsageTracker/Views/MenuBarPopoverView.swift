import SwiftUI
import AppKit
import CursorUsageCore

struct MenuBarPopoverView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme
    /// When set (separate menu bar items), lock this popover to one account — no tabs.
    var focusedAccountID: UUID? = nil
    var onIdealHeight: ((CGFloat) -> Void)? = nil
    @State private var selectedTab: UUID?
    @State private var bodyHeight: CGFloat = 0
    @State private var topChromeHeight: CGFloat = 70
    @State private var bottomChromeHeight: CGFloat = 44
    @State private var showReauth = false
    @AppStorage(AppInstall.bannerDismissedKey) private var installBannerDismissed = false

    private var popoverMaxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) * 0.72
    }

    private var maxBodyHeight: CGFloat {
        max(80, popoverMaxHeight - topChromeHeight - bottomChromeHeight)
    }

    private var displayed: AccountRuntime? {
        if let focusedAccountID {
            return store.account(focusedAccountID)
        }
        if let selectedTab, let account = store.account(selectedTab) {
            return account
        }
        return store.activeAccount
    }

    private var showAccountTabs: Bool {
        focusedAccountID == nil
            && store.connections.count > 1
            && store.preferences.menuBarAccountMode != .separateItems
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                if showAccountTabs {
                    accountTabs
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                }

                header
                    .padding(.horizontal, 14)
                    .padding(.top, showAccountTabs ? 4 : 12)
                    .padding(.bottom, 8)
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
            }
            .layoutPriority(1)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: PopoverTopChromeHeightKey.self, value: geo.size.height)
                }
            }

            ScrollView(.vertical, showsIndicators: bodyHeight > maxBodyHeight + 1) {
                popoverBody
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(key: PopoverBodyHeightKey.self, value: geo.size.height)
                        }
                    }
            }
            .frame(height: min(max(bodyHeight, 1), maxBodyHeight), alignment: .top)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: 0) {
                Divider()
                footer
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
            .background {
                GeometryReader { geo in
                    Color.clear.preference(key: PopoverBottomChromeHeightKey.self, value: geo.size.height)
                }
            }
        }
        .frame(width: store.preferences.interfaceSize.popoverWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
        .appThemed(store.preferences)
        .onPreferenceChange(PopoverBodyHeightKey.self) { newValue in
            if abs(newValue - bodyHeight) > 0.5 { bodyHeight = newValue }
            reportIdealHeight(body: newValue, top: topChromeHeight, bottom: bottomChromeHeight)
        }
        .onPreferenceChange(PopoverTopChromeHeightKey.self) { newValue in
            if abs(newValue - topChromeHeight) > 0.5 { topChromeHeight = newValue }
            reportIdealHeight(body: bodyHeight, top: newValue, bottom: bottomChromeHeight)
        }
        .onPreferenceChange(PopoverBottomChromeHeightKey.self) { newValue in
            if abs(newValue - bottomChromeHeight) > 0.5 { bottomChromeHeight = newValue }
            reportIdealHeight(body: bodyHeight, top: topChromeHeight, bottom: newValue)
        }
        .onAppear {
            selectedTab = focusedAccountID ?? store.activeAccountID
            store.refreshLocalActivity()
        }
        .onChange(of: store.activeAccountID) { _, newValue in
            if focusedAccountID == nil, selectedTab == nil {
                selectedTab = newValue
            }
        }
        .sheet(isPresented: $showReauth) {
            reauthSheet
        }
    }

    private func reportIdealHeight(body: CGFloat, top: CGFloat, bottom: CGFloat) {
        let scroll = min(max(body, 1), max(80, popoverMaxHeight - top - bottom))
        let total = top + scroll + bottom
        guard total > 1 else { return }
        onIdealHeight?(total)
    }

    @ViewBuilder
    private var popoverBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !AppInstall.isRunningFromApplications, !installBannerDismissed {
                installBanner
            }
            if displayed != nil, displayed?.isAuthenticated != true, !store.connections.isEmpty {
                sessionExpiredBanner
            }
            if let snapshot = displayed?.snapshot {
                usageBody(snapshot)
            } else if displayed?.isRefreshing == true || store.isRefreshing {
                ProgressView("Loading usage…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            } else if store.connections.isEmpty {
                signInPrompt
            } else {
                Text(displayed?.lastError ?? store.lastError ?? "No usage data yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var sessionExpiredBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                displayed?.lastError ?? "Session expired — sign in again.",
                systemImage: "exclamationmark.triangle.fill"
            )
            .appFont(.caption, weight: .semibold)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
            Button {
                showReauth = true
            } label: {
                Label("Sign in again", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }

    private var installBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Desktop widgets need this app in Applications.", systemImage: "rectangle.on.rectangle")
                .appFont(.caption, weight: .semibold)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button {
                    do {
                        _ = try AppInstall.copyRunningAppToApplications()
                    } catch {
                        // Keep the banner; About has the same installer with an error line.
                    }
                } label: {
                    Label("Install to Applications", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button("Not now") {
                    installBannerDismissed = true
                }
                .controlSize(.small)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private var reauthSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sign in again")
                    .font(.headline)
                Spacer()
                Button("Cancel") { showReauth = false }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            LoginWebView { token in
                showReauth = false
                let replacing = displayed?.id ?? store.activeAccountID
                Task {
                    try? await store.saveSessionToken(token, replacing: replacing)
                }
            } onCancel: {
                showReauth = false
            }
        }
        .frame(width: 720, height: 640)
    }

    private var accountTabs: some View {
        HStack(spacing: 6) {
            ForEach(store.accounts) { account in
                let selected = (selectedTab ?? store.activeAccountID) == account.id
                Button {
                    selectedTab = account.id
                    if store.preferences.menuBarAccountMode == .activeOnly {
                        store.setActive(id: account.id)
                    }
                } label: {
                    Text(account.connection.displayLabel)
                        .appFont(.caption, weight: .semibold)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                        )
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        let snapshot = displayed?.snapshot
        return HStack(alignment: .center, spacing: 8) {
            AppLogo(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot?.planDisplayName ?? "Cursor")
                    .appFont(.headline)
                if let fetched = snapshot?.fetchedAt {
                    Text("Updated \(fetched.formatted(date: .omitted, time: .shortened))")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                } else if let email = displayed?.connection.email {
                    Text(email)
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Subscription")
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()

            Spacer(minLength: 6)

            Button {
                Task {
                    if let id = displayed?.id {
                        await store.refreshAccount(id)
                    } else {
                        await store.refresh()
                    }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(displayed?.isRefreshing == true || displayed?.isAuthenticated != true)
            .help("Refresh")
        }
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Not signed in", systemImage: "person.crop.circle.badge.exclamationmark")
                .appFont(.subheadline, weight: .semibold)
            Text("Open Settings → Authentication to connect with Cursor, local session, or a pasted token.")
                .appFont(.caption)
                .foregroundStyle(.secondary)
            if store.preferences.popover.thisMacActivity
                || store.preferences.popover.localRecentChats
                || store.preferences.popover.cloudAgents
            {
                PopoverAgentsCard(account: displayed)
            }
            SettingsOpenLink {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var warningHits: [UsageSnapshot.MenuBarWarningHit] {
        displayed.map { store.menuBarPresentation(for: $0.id).warningHits }
            ?? store.menuBarPresentation.warningHits
    }

    @ViewBuilder
    private func alertList(_ hits: [UsageSnapshot.MenuBarWarningHit]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(hits) { hit in
                HStack(alignment: .center, spacing: 8) {
                    Circle()
                        .fill(theme.danger)
                        .frame(width: 7, height: 7)
                    Button {
                        AppActivation.openSettingsViaLinkFallback()
                    } label: {
                        Text("\(hit.channel.title) \(hit.current)  ·  alert \(hit.threshold)")
                            .appFont(.caption)
                            .foregroundStyle(theme.danger)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .help("\(hit.sentence). Click to change the alert in Settings → General.")

                    Button {
                        store.snoozeMenuBarWarning(hit.channel)
                    } label: {
                        Image(systemName: "xmark")
                            .appFont(.caption2, weight: .bold)
                            .foregroundStyle(.secondary)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .help("Hide \(hit.channel.title) until it drops back under \(hit.threshold).")
                }
            }

            if hits.count > 1 {
                HStack {
                    Spacer()
                    Button("Clear all") {
                        store.snoozeAllMenuBarWarnings()
                    }
                    .appFont(.caption2, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
                    .help("Hide until usage drops back under the alert. Does not change the threshold.")
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.danger.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Usage alarms")
        .accessibilityValue(hits.map(\.sentence).joined(separator: ". "))
    }

    @ViewBuilder
    private func usageBody(_ snapshot: UsageSnapshot) -> some View {
        let t = store.preferences.popover
        let hits = warningHits

        VStack(alignment: .leading, spacing: 12) {
            if !hits.isEmpty {
                alertList(hits)
            }

            if t.cursorModelsPercent || t.otherModelsPercent || t.totalPercent {
                Text("Included usage")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if t.cursorModelsPercent, let p = snapshot.cursorModelsPercentUsed {
                    PopoverPoolRow(
                        title: "Cursor Models",
                        systemImage: "sparkles",
                        percent: p,
                        caption: "First-party included pool"
                    )
                }
                if t.otherModelsPercent, let p = snapshot.otherModelsPercentUsed {
                    PopoverPoolRow(
                        title: "Other Models",
                        systemImage: "cpu",
                        percent: p,
                        caption: "API / third-party included pool"
                    )
                }
                if t.totalPercent, let p = snapshot.totalPercentUsed {
                    PopoverPoolRow(
                        title: "Total included",
                        systemImage: "chart.pie.fill",
                        percent: p,
                        caption: nil
                    )
                }
            }

            if t.planSpend || t.bonus || t.onDemand || t.daysRemaining || t.burnRateEstimate {
                VStack(alignment: .leading, spacing: 8) {
                    if t.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                        Label {
                            HStack {
                                Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                                    .appFont(.subheadline, weight: .semibold, mono: true)
                                Text("base")
                                    .appFont(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundStyle(theme.spend)
                        }
                        if t.bonus, let bonus = snapshot.bonusCents, bonus > 0 {
                            Label("+\(MenuBarFormatter.usd(bonus)) bonus", systemImage: "gift.fill")
                                .appFont(.caption)
                                .foregroundStyle(theme.spend)
                        }
                    }

                    if t.onDemand {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("On-demand", systemImage: "creditcard.fill")
                                Spacer()
                                Text(snapshot.onDemandEnabled ? "Enabled" : "Disabled")
                                    .appFont(.caption, weight: .bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule().fill(
                                            (snapshot.onDemandEnabled ? theme.ok : theme.danger).opacity(0.18)
                                        )
                                    )
                                    .foregroundStyle(snapshot.onDemandEnabled ? theme.ok : theme.danger)
                            }
                            .appFont(.subheadline)

                            if let used = snapshot.onDemandUsedCents {
                                HStack {
                                    Text("Billable usage")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(MenuBarFormatter.usd(used))
                                        .appFont(.subheadline, weight: .semibold, mono: true)
                                }
                                .appFont(.caption)
                            }

                            HStack {
                                Text("Usage limit")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(onDemandLimitLabel(snapshot))
                                    .appFont(.caption, weight: .semibold, mono: true)
                            }
                            .appFont(.caption)
                        }
                    }

                    if t.daysRemaining, let end = snapshot.billingCycleEnd, let days = snapshot.daysRemainingInCycle {
                        Label(
                            "Ends \(end.formatted(date: .abbreviated, time: .shortened)) · \(days)d left",
                            systemImage: "calendar"
                        )
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if t.burnRateEstimate, let pace = snapshot.pace() {
                        Label(pace.caption, systemImage: "speedometer")
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }

            if t.modelsThisPeriod {
                PopoverModelsThisPeriodCard(snapshot: snapshot)
            }

            if t.cycleChart, !snapshot.cycleHistory.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Spend by cycle")
                        .appFont(.caption, weight: .semibold)
                        .foregroundStyle(.secondary)
                    CycleSpendChart(cycles: snapshot.cycleHistory, height: 88)
                    if let caption = snapshot.cycleComparisonCaption {
                        Text(caption)
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let caption = snapshot.cycleComparisonCaption {
                Text(caption)
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }

            if t.thisMacActivity || t.localRecentChats || t.cloudAgents {
                PopoverAgentsCard(account: displayed)
            }

            if let error = displayed?.lastError ?? store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .appFont(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func onDemandLimitLabel(_ snapshot: UsageSnapshot) -> String {
        if snapshot.isOnDemandUnlimited {
            return "Unlimited"
        }
        if let limit = snapshot.onDemandLimitCents {
            return MenuBarFormatter.usd(limit)
        }
        return snapshot.onDemandEnabled ? "—" : "$0"
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                SettingsOpenLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .keyboardShortcut(",", modifiers: .command)
                if let snapshot = displayed?.snapshot {
                    Button {
                        UsageExportPanel.present(snapshot: snapshot)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
                Spacer(minLength: 8)
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "xmark.circle")
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .labelStyle(.titleAndIcon)
            .controlSize(.small)

            Text((AppAbout.organization))
                .appFont(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
        }
    }
}

private struct PopoverPoolRow: View {
    let title: String
    let systemImage: String
    let percent: Double
    let caption: String?
    @Environment(\.appTheme) private var theme

    var body: some View {
        let tint = theme.color(forPool: title, percent: percent)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 16)
                Text(title)
                    .appFont(.subheadline, weight: .semibold)
                Spacer()
                Text("\(Int(percent.rounded()))%")
                    .appFont(.subheadline, weight: .bold, mono: true)
                    .foregroundStyle(tint)
            }
            UsageProgressBar(percent: percent, tint: tint, pattern: .forPool(title))
            if let caption {
                Text(caption)
                    .appFont(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 24)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }
}

private struct PopoverModelsThisPeriodCard: View {
    let snapshot: UsageSnapshot
    private let maxRows = 8
    @Environment(\.appTheme) private var theme

    var body: some View {
        let rows = Array(snapshot.modelBreakdown.prefix(maxRows))
        let overflow = max(0, snapshot.modelBreakdown.count - rows.count)

        VStack(alignment: .leading, spacing: 8) {
            Label("Models this period", systemImage: "list.bullet.rectangle")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)

            if rows.isEmpty {
                Text("No model spend yet this period.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(rows) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .appFont(.caption)
                                    .foregroundStyle(theme.otherModels.opacity(0.75))
                                Text(row.model)
                                    .appFont(.caption)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer(minLength: 8)
                                Text(MenuBarFormatter.usd(row.totalCents))
                                    .appFont(.caption, weight: .medium, mono: true)
                            }
                            if let tokens = MenuBarFormatter.tokenCaption(row) {
                                Text(tokens)
                                    .appFont(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 24)
                            }
                        }
                    }

                    if overflow > 0 {
                        Text("+\(overflow) more in Settings → Included")
                            .appFont(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let total = snapshot.totalModelCostCents {
                        Divider()
                        HStack {
                            Text("Total")
                                .appFont(.caption, weight: .semibold)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(MenuBarFormatter.usd(total))
                                    .appFont(.caption, weight: .bold, mono: true)
                                if let tokens = MenuBarFormatter.tokenCaption(
                                    input: snapshot.totalInputTokens,
                                    output: snapshot.totalOutputTokens
                                ) {
                                    Text(tokens)
                                        .appFont(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct PopoverAgentsCard: View {
    @EnvironmentObject private var store: UsageStore
    var account: AccountRuntime?

    private var toggles: DisplayPreferences.SurfaceToggles { store.preferences.popover }
    private var mac: CursorProcessSnapshot { store.thisMac }

    private var showThisMac: Bool {
        toggles.thisMacActivity || (toggles.localRecentChats && !store.localComposers.isEmpty)
    }

    private var showCLI: Bool {
        let status = toggles.thisMacActivity && mac.showsCLIRow
        let chats = toggles.localRecentChats && (mac.showsCLIRow || !store.localCLISessions.isEmpty)
        return status || chats
    }

    private var showCloud: Bool { toggles.cloudAgents }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agents")
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if showThisMac {
                agentGroup(title: "This Mac", systemImage: "laptopcomputer") {
                    if toggles.thisMacActivity {
                        statusRow(
                            systemImage: mac.isEditorRunning ? "laptopcomputer" : "laptopcomputer.slash",
                            text: mac.summaryLine,
                            active: mac.isEditorRunning,
                            badge: mac.windowCount > 0 ? "\(mac.windowCount)" : nil
                        )
                    }
                    if toggles.localRecentChats {
                        chatList(store.localComposers, empty: "No recent editor chats.")
                    }
                }
            }

            if showCLI {
                agentGroup(title: "CLI", systemImage: "terminal") {
                    if toggles.thisMacActivity, mac.showsCLIRow {
                        statusRow(
                            systemImage: mac.cliRunning ? "terminal.fill" : "terminal",
                            text: mac.cliSummaryLine,
                            active: mac.cliRunning,
                            badge: mac.cliProcessCount > 0 ? "\(mac.cliProcessCount)" : nil
                        )
                    }
                    if toggles.localRecentChats {
                        chatList(store.localCLISessions, empty: "No recent CLI sessions.")
                    }
                }
            }

            if showCloud {
                agentGroup(title: "Cloud", systemImage: "cloud") {
                    cloudBody
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func agentGroup<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .appFont(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func statusRow(systemImage: String, text: String, active: Bool, badge: String?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(active ? Color.accentColor : Color.secondary)
                .frame(width: 16)
            Text(text)
                .appFont(.caption)
                .foregroundStyle(active ? Color.primary : Color.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if let badge {
                Text(badge)
                    .appFont(.caption2, weight: .bold, mono: true)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    @ViewBuilder
    private func chatList(_ rows: [LocalComposerSummary], empty: String) -> some View {
        if rows.isEmpty {
            Text(empty)
                .appFont(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(row.name)
                                .appFont(.caption, weight: .medium)
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(row.activityModeLabel)
                                .appFont(.caption2, weight: .semibold)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            if let model = row.model {
                                Text(model)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            if let folder = row.projectFolder {
                                Text(folder)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 4)
                            if let updated = row.updatedAt {
                                Text(MenuBarFormatter.relative(updated))
                            }
                        }
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var cloudBody: some View {
        if account?.hasCloudAPIKey != true {
            Text("Add a Cloud Agents API key in Settings → Authentication.")
                .appFont(.caption)
                .foregroundStyle(.secondary)
        } else if let error = account?.cloudAgentsError {
            Text(error)
                .appFont(.caption)
                .foregroundStyle(.orange)
        } else if let agents = account?.cloudAgents, !agents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(agents.prefix(8)) { agent in
                    Button {
                        if let url = agent.url {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(agent.isRunning ? Color.green : Color.secondary.opacity(0.45))
                                .frame(width: 7, height: 7)
                            Text(agent.name)
                                .appFont(.caption, weight: .medium)
                                .lineLimit(1)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Text(agent.displayStatus.lowercased())
                                .appFont(.caption2, weight: .semibold)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            Text("No active cloud agents.")
                .appFont(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PopoverBodyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct PopoverTopChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct PopoverBottomChromeHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
