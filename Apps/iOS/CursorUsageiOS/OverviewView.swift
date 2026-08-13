import SwiftUI
import CursorUsageCore

struct OverviewView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

    private var account: AccountRuntime? { store.activeAccount }
    private var layout: DisplayPreferences.SurfaceToggles { store.preferences.popover }

    var body: some View {
        NavigationStack {
            Group {
                if account?.isAuthenticated != true {
                    unsignedHero(
                        title: "Not signed in",
                        detail: "Add a Cursor session in Accounts. Sign in with Cursor or paste a token — this phone cannot read the Mac IDE."
                    )
                } else if let snapshot = account?.snapshot {
                    usageList(snapshot)
                } else if store.isRefreshing || account?.isRefreshing == true {
                    ProgressView("Loading usage…")
                } else {
                    unsignedHero(
                        title: "No usage data yet",
                        detail: account?.lastError ?? store.lastError ?? "Pull to refresh after signing in."
                    )
                }
            }
            .navigationTitle("Cursor Usage Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(account?.isAuthenticated != true || store.isRefreshing)
                }
            }
            .refreshable { await store.refresh() }
        }
    }

    @ViewBuilder
    private func usageList(_ snapshot: UsageSnapshot) -> some View {
        List {
            Section {
                HStack(spacing: 12) {
                    AppLogo(size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.planDisplayName)
                            .font(.headline)
                        Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if store.connections.count > 1 {
                Section("Account") {
                    Picker("Active", selection: activeBinding) {
                        ForEach(store.accounts) { item in
                            Text(item.connection.displayLabel).tag(item.id)
                        }
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

            if layout.planSpend || layout.bonus || layout.onDemand || layout.daysRemaining {
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
                }
            }

            if layout.modelsThisPeriod, !snapshot.modelBreakdown.isEmpty {
                Section("Models this period") {
                    ForEach(Array(snapshot.modelBreakdown.prefix(8))) { row in
                        LabeledContent(row.model) {
                            Text(MenuBarFormatter.usd(row.totalCents))
                                .monospacedDigit()
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

            if let error = account?.lastError ?? store.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func unsignedHero(title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            AppLogo(size: 64)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activeBinding: Binding<UUID> {
        Binding(
            get: { store.activeAccountID ?? store.connections.first?.id ?? UUID() },
            set: { store.setActive(id: $0) }
        )
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

    private func onDemandLabel(_ snapshot: UsageSnapshot) -> String {
        if !snapshot.onDemandEnabled { return "Off" }
        if snapshot.isOnDemandUnlimited { return "Unlimited" }
        if let limit = snapshot.onDemandLimitCents {
            return MenuBarFormatter.usd(limit)
        }
        return "On"
    }
}
