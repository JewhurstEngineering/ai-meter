import SwiftUI
import CursorUsageCore

struct OverviewView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

    private var layout: DisplayPreferences.SurfaceToggles { store.preferences.popover }

    @State private var showReauth = false

    var body: some View {
        NavigationStack {
            PhoneAccountPager { account in
                accountPage(account)
            }
            .navigationTitle("Cursor Usage Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let snapshot = store.snapshot,
                       let url = try? UsageExport.writeTemporaryCSV(snapshot)
                    {
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.activeAccount?.isAuthenticated != true || store.isRefreshing)
                }
            }
            .sheet(isPresented: $showReauth) {
                NavigationStack {
                    LoginWebView { token in
                        showReauth = false
                        let replacing = store.activeAccountID
                        Task {
                            try? await store.saveSessionToken(token, replacing: replacing)
                        }
                    }
                    .ignoresSafeArea()
                    .navigationTitle("Sign in again")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showReauth = false }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func accountPage(_ account: AccountRuntime?) -> some View {
        Group {
            if account?.isAuthenticated != true, store.connections.isEmpty {
                unsignedHero(
                    title: "Not signed in",
                    detail: "Add a Cursor session in Accounts. Sign in with Cursor or paste a token — this phone cannot read the Mac IDE."
                )
            } else if let snapshot = account?.snapshot {
                usageList(snapshot, account: account)
            } else if account?.isRefreshing == true || store.isRefreshing {
                ProgressView("Loading usage…")
            } else if account?.isAuthenticated != true {
                unsignedHero(
                    title: "Session expired",
                    detail: account?.lastError ?? "Sign in again from Accounts.",
                    showSignIn: true
                )
            } else {
                unsignedHero(
                    title: "No usage data yet",
                    detail: account?.lastError ?? store.lastError ?? "Pull to refresh after signing in."
                )
            }
        }
        .refreshable { await store.refresh() }
    }

    @ViewBuilder
    private func usageList(_ snapshot: UsageSnapshot, account: AccountRuntime?) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    AppLogo(size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.planDisplayName)
                            .font(.headline)
                        if let label = account?.connection.displayLabel {
                            Text(label)
                                .font(.subheadline.weight(.medium))
                        }
                        Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                PhoneAccountSwitcherChrome()
            }

            if account?.isAuthenticated != true {
                Section {
                    Label(
                        account?.lastError ?? "Session expired — sign in again.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    Button {
                        showReauth = true
                    } label: {
                        Label("Sign in again", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }

            if layout.cursorModelsPercent || layout.otherModelsPercent || layout.totalPercent {
                Section("Included usage") {
                    if layout.cursorModelsPercent {
                        poolRow("Cursor Models", systemImage: "sparkles", percent: snapshot.cursorModelsPercentUsed)
                    }
                    if layout.otherModelsPercent {
                        poolRow("Other Models", systemImage: "cpu", percent: snapshot.otherModelsPercentUsed)
                    }
                    if layout.totalPercent {
                        poolRow("Total included", systemImage: "chart.pie.fill", percent: snapshot.totalPercentUsed)
                    }
                }
            }

            if layout.planSpend || layout.bonus || layout.onDemand || layout.daysRemaining || layout.burnRateEstimate {
                Section("Spend") {
                    if layout.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                        LabeledContent("Spend") {
                            Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                                .monospacedDigit()
                        }
                    }
                    if layout.bonus, let bonus = snapshot.bonusCents, bonus > 0 {
                        LabeledContent("Bonus") {
                            Text("+\(MenuBarFormatter.usd(bonus))")
                                .monospacedDigit()
                        }
                    }
                    if layout.onDemand {
                        LabeledContent("On-demand") {
                            Text(onDemandLabel(snapshot))
                        }
                        if let used = snapshot.onDemandUsedCents {
                            LabeledContent("Billable") {
                                Text(MenuBarFormatter.usd(used))
                                    .monospacedDigit()
                            }
                        }
                    }
                    if layout.daysRemaining, let days = snapshot.daysRemainingInCycle {
                        LabeledContent("Cycle") {
                            Text("\(days)d left")
                                .monospacedDigit()
                        }
                    }
                    if layout.burnRateEstimate, let pace = snapshot.pace() {
                        Text(pace.caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if layout.cycleChart, !snapshot.cycleHistory.isEmpty {
                Section("Spend by cycle") {
                    CycleSpendChart(cycles: snapshot.cycleHistory, height: 140)
                    if let caption = snapshot.cycleComparisonCaption {
                        Text(caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if layout.modelsThisPeriod, !snapshot.modelBreakdown.isEmpty {
                Section("Models this period") {
                    ForEach(Array(snapshot.modelBreakdown.prefix(8))) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            LabeledContent(row.model) {
                                Text(MenuBarFormatter.usd(row.totalCents))
                                    .monospacedDigit()
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

            if layout.cloudAgents {
                cloudAgentsSection(account)
            }

            if account?.isAuthenticated == true, let error = account?.lastError ?? store.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Link(destination: AppAbout.dashboardURL) {
                        Label("Open Cursor dashboard", systemImage: "globe")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func unsignedHero(title: String, detail: String, showSignIn: Bool = false) -> some View {
        VStack(spacing: 12) {
            AppLogo(size: 64)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if showSignIn {
                Button {
                    showReauth = true
                } label: {
                    Label("Sign in again", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
            }
            PhoneAccountSwitcherChrome()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func poolRow(_ title: String, systemImage: String, percent: Double?) -> some View {
        let tint = theme.color(forPool: title, percent: percent ?? 0)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(tint)
                Spacer()
                Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(tint)
            }
            UsageProgressBar(
                percent: percent ?? 0,
                tint: tint,
                pattern: .forPool(title)
            )
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func cloudAgentsSection(_ account: AccountRuntime?) -> some View {
        Section {
            if account?.hasCloudAPIKey != true {
                Text("Add a Cloud Agents API key in Accounts.")
                    .foregroundStyle(.secondary)
            } else if let error = account?.cloudAgentsError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if let agents = account?.cloudAgents, !agents.isEmpty {
                ForEach(agents.prefix(8)) { agent in
                    if let url = agent.url {
                        Link(destination: url) {
                            cloudAgentRow(agent)
                        }
                    } else {
                        cloudAgentRow(agent)
                    }
                }
            } else {
                Text("No active cloud agents.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Agents")
        } footer: {
            Text("Cloud runs for this account. This Mac and CLI only appear on the Mac app.")
        }
    }

    private func cloudAgentRow(_ agent: CloudAgentSummary) -> some View {
        HStack {
            Circle()
                .fill(agent.isRunning ? Color.green : Color.secondary.opacity(0.45))
                .frame(width: 8, height: 8)
            Text(agent.name)
                .lineLimit(1)
            Spacer()
            Text(agent.displayStatus.lowercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func onDemandLabel(_ snapshot: UsageSnapshot) -> String {
        if !snapshot.onDemandEnabled { return "Off" }
        if snapshot.isOnDemandUnlimited { return "Unlimited" }
        if let limit = snapshot.onDemandLimitCents {
            return MenuBarFormatter.usd(limit)
        }
        return "On"
    }
}
