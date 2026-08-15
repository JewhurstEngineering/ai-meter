import SwiftUI
import AppKit
import AIMeterCore

private enum PopoverPane: Equatable {
    case all
    case account(UUID)
}

struct MenuBarPopoverView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme
    /// When set (separate menu bar items), lock this popover to one account — no tabs.
    var focusedAccountID: UUID? = nil
    var onIdealHeight: ((CGFloat) -> Void)? = nil
    @State private var pane: PopoverPane = .all
    @State private var bodyHeight: CGFloat = 0
    @State private var topChromeHeight: CGFloat = 70
    @State private var bottomChromeHeight: CGFloat = 44
    @State private var showReauth = false
    @State private var installBusy = false
    @State private var installCopied = false
    @State private var installError: String?
    @AppStorage(AppInstall.bannerDismissedKey) private var installBannerDismissed = false

    private var popoverMaxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) * 0.72
    }

    private var maxBodyHeight: CGFloat {
        max(80, popoverMaxHeight - topChromeHeight - bottomChromeHeight)
    }

    private var showingAll: Bool {
        focusedAccountID == nil && showAccountTabs && pane == .all
    }

    private var displayed: AccountRuntime? {
        if let focusedAccountID {
            return store.account(focusedAccountID)
        }
        if showingAll { return nil }
        if case .account(let id) = pane {
            return store.account(id) ?? store.activeAccount
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
                Group {
                    if showingAll {
                        allAccountsBody
                    } else {
                        popoverBody
                    }
                }
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
            if let focusedAccountID {
                pane = .account(focusedAccountID)
            } else if store.connections.count > 1 {
                pane = .all
            } else if let id = store.activeAccountID {
                pane = .account(id)
            }
            store.refreshLocalActivity()
        }
        .onChange(of: store.activeAccountID) { _, newValue in
            if focusedAccountID == nil, pane == .all, store.connections.count < 2, let newValue {
                pane = .account(newValue)
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
    private var allAccountsBody: some View {
        let t = store.preferences.popover
        VStack(alignment: .leading, spacing: 10) {
            if !AppInstall.isRunningFromApplications, !installBannerDismissed {
                installBanner
            }
            ForEach(store.accounts) { account in
                allAccountCard(account, toggles: t)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func allAccountCard(
        _ account: AccountRuntime,
        toggles: DisplayPreferences.SurfaceToggles
    ) -> some View {
        let provider = account.connection.provider
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                pane = .account(account.id)
                if store.preferences.menuBarAccountMode == .activeOnly {
                    store.setActive(id: account.id)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: provider.systemImage)
                    Text(account.connection.displayLabel)
                        .appFont(.subheadline, weight: .semibold)
                    Spacer(minLength: 4)
                    Text(account.snapshot?.planDisplayName ?? provider.displayName)
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .appFont(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .help("Open \(account.connection.displayLabel) details")

            if let snapshot = account.snapshot {
                let windows = visibleWindows(snapshot, toggles: toggles)
                if windows.isEmpty {
                    Text("No usage bars enabled for this provider.")
                        .appFont(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(windows) { window in
                        PopoverPoolRow(
                            title: window.title,
                            systemImage: icon(for: window.role),
                            percent: window.percentUsed,
                            caption: nil,
                            role: window.role
                        )
                    }
                }
            } else if account.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(account.lastError ?? "No usage data yet.")
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
            } else if let error = displayed?.lastError {
                Text(error)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else if displayed?.isRefreshing == true {
                ProgressView("Loading usage…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            } else if store.connections.isEmpty {
                signInPrompt
            } else {
                Text("No usage data yet.")
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
                reconnectDisplayed()
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

            if installCopied {
                Text("Copied to Applications. This Xcode/DerivedData copy is still running — widgets only appear after you open the installed app.")
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button {
                        AppInstall.launchInstalledAndTerminate()
                    } label: {
                        Label("Quit & open installed app", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Button("Reveal in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([AppInstall.installedAppURL])
                    }
                    .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Button {
                        installToApplications()
                    } label: {
                        if installBusy {
                            Label("Copying…", systemImage: "arrow.triangle.2.circlepath")
                        } else {
                            Label("Install to Applications", systemImage: "square.and.arrow.down")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(installBusy)
                    Button("Not now") {
                        installBannerDismissed = true
                    }
                    .controlSize(.small)
                    .disabled(installBusy)
                }
            }

            if let installError {
                Text(installError)
                    .appFont(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func installToApplications() {
        installBusy = true
        installError = nil
        Task { @MainActor in
            do {
                _ = try await Task.detached(priority: .userInitiated) {
                    try AppInstall.copyRunningAppToApplications()
                }.value
                installCopied = true
            } catch {
                installError = "Couldn’t install: \(error.localizedDescription)"
            }
            installBusy = false
        }
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
            tabChip("All", selected: pane == .all, systemImage: "square.grid.2x2") {
                pane = .all
            }
            ForEach(store.accounts) { account in
                let selected = {
                    if case .account(let id) = pane { return id == account.id }
                    return false
                }()
                tabChip(account.connection.displayLabel, selected: selected, systemImage: account.connection.provider.systemImage) {
                    pane = .account(account.id)
                    if store.preferences.menuBarAccountMode == .activeOnly {
                        store.setActive(id: account.id)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func tabChip(_ title: String, selected: Bool, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .appFont(.caption2)
                Text(title)
                    .appFont(.caption, weight: .semibold)
                    .lineLimit(1)
            }
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

    private var header: some View {
        let snapshot = displayed?.snapshot
        return HStack(alignment: .center, spacing: 8) {
            AppLogo(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                if showingAll {
                    Text("All accounts")
                        .appFont(.headline)
                    Text(store.accounts.map(\.connection.provider.displayName).joined(separator: " · "))
                        .appFont(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(snapshot?.planDisplayName ?? displayed?.connection.provider.displayName ?? AppAbout.productName)
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
            }
            .fixedSize()

            Spacer(minLength: 6)

            Button {
                Task {
                    if showingAll {
                        await store.refresh()
                    } else if let id = displayed?.id {
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
            .disabled(showingAll ? store.isRefreshing : (displayed?.isRefreshing == true || displayed?.isAuthenticated != true))
            .help("Refresh")
        }
    }

    private func reconnectDisplayed() {
        let provider = displayed?.connection.provider ?? .cursor
        switch provider {
        case .claude:
            Task {
                do { try await store.connectClaude() }
                catch { /* lastError is set on the store */ }
            }
        case .codex:
            Task {
                do { try await store.connectCodex() }
                catch { /* lastError is set on the store */ }
            }
        case .cursor:
            showReauth = true
        }
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Not signed in", systemImage: "person.crop.circle.badge.exclamationmark")
                .appFont(.subheadline, weight: .semibold)
            Text("Open Settings → Authentication to connect Cursor, Claude Code, or Codex.")
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

            if t.cursorModelsPercent || t.otherModelsPercent || t.totalPercent || t.sessionPercent || t.weeklyPercent {
                Text(snapshot.provider == .cursor ? "Included usage" : "Usage windows")
                    .appFont(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(visibleWindows(snapshot, toggles: t)) { window in
                    PopoverPoolRow(
                        title: window.title,
                        systemImage: icon(for: window.role),
                        percent: window.percentUsed,
                        caption: windowCaption(window),
                        role: window.role
                    )
                }
            }

            if t.planSpend || t.bonus || t.onDemand || t.daysRemaining || t.burnRateEstimate {
                VStack(alignment: .leading, spacing: 8) {
                    if snapshot.provider == .cursor, t.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
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
                        if snapshot.provider == .cursor {
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
                        } else if let spend = snapshot.spend {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(spend.title, systemImage: "creditcard.fill")
                                    Spacer()
                                    Text(spend.unlimited ? "Unlimited" : (spend.enabled ? "On" : "Off"))
                                        .appFont(.caption, weight: .bold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule().fill(
                                                (spend.enabled ? theme.ok : theme.danger).opacity(0.18)
                                            )
                                        )
                                        .foregroundStyle(spend.enabled ? theme.ok : theme.danger)
                                }
                                .appFont(.subheadline)
                                if let used = spend.usedCents, let limit = spend.limitCents {
                                    HStack {
                                        Text("Used")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                                            .appFont(.subheadline, weight: .semibold, mono: true)
                                    }
                                    .appFont(.caption)
                                } else if let remaining = spend.remainingCents {
                                    HStack {
                                        Text("Balance")
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(MenuBarFormatter.usd(remaining))
                                            .appFont(.subheadline, weight: .semibold, mono: true)
                                    }
                                    .appFont(.caption)
                                }
                            }
                        }
                    }

                    if t.daysRemaining {
                        if snapshot.provider == .cursor, let end = snapshot.billingCycleEnd, let days = snapshot.daysRemainingInCycle {
                            Label(
                                "Ends \(end.formatted(date: .abbreviated, time: .shortened)) · \(days)d left",
                                systemImage: "calendar"
                            )
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                        } else if let reset = snapshot.nextResetAt {
                            Label(
                                "Resets \(reset.formatted(date: .omitted, time: .shortened)) · \(MenuBarFormatter.relative(reset))",
                                systemImage: "clock.arrow.circlepath"
                            )
                            .appFont(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    if snapshot.provider == .cursor, t.burnRateEstimate, let pace = snapshot.pace() {
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

            if snapshot.provider == .cursor, t.modelsThisPeriod {
                PopoverModelsThisPeriodCard(snapshot: snapshot)
            }

            if snapshot.provider == .cursor, t.cycleChart, !snapshot.cycleHistory.isEmpty {
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
            } else if snapshot.provider == .cursor, let caption = snapshot.cycleComparisonCaption {
                Text(caption)
                    .appFont(.caption)
                    .foregroundStyle(.secondary)
            }

            if snapshot.provider == .cursor, t.thisMacActivity || t.localRecentChats || t.cloudAgents {
                PopoverAgentsCard(account: displayed)
            }

            if let error = displayed?.lastError ?? store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .appFont(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func visibleWindows(
        _ snapshot: UsageSnapshot,
        toggles: DisplayPreferences.SurfaceToggles
    ) -> [QuotaWindow] {
        snapshot.effectiveWindows.filter { window in
            switch window.role {
            case .cursorModels: return toggles.cursorModelsPercent
            case .otherModels: return toggles.otherModelsPercent
            case .totalIncluded: return toggles.totalPercent
            case .session: return toggles.sessionPercent
            case .weekly: return toggles.weeklyPercent
            case .extra: return true
            }
        }
    }

    private func windowCaption(_ window: QuotaWindow) -> String? {
        switch window.role {
        case .cursorModels: return "First-party included pool"
        case .otherModels: return "API / third-party included pool"
        case .session, .weekly, .extra:
            if let reset = window.resetsAt {
                return "Resets \(MenuBarFormatter.relative(reset))"
            }
            return nil
        case .totalIncluded:
            return nil
        }
    }

    private func icon(for role: QuotaWindowRole) -> String {
        switch role {
        case .cursorModels: return "sparkles"
        case .otherModels: return "cpu"
        case .totalIncluded: return "chart.pie.fill"
        case .session: return "clock"
        case .weekly: return "calendar"
        case .extra: return "square.grid.2x2"
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
    var role: QuotaWindowRole = .extra
    @Environment(\.appTheme) private var theme

    var body: some View {
        let tint = theme.color(forRole: role, percent: percent)
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
            UsageProgressBar(percent: percent, tint: tint, pattern: .forRole(role))
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
