import SwiftUI
import CursorUsageCore

struct OverviewView: View {
    @EnvironmentObject private var store: UsageStore

    private var account: AccountRuntime? { store.activeAccount }

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
                HStack {
                    Spacer()
                    AppLogo(size: 72)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                LabeledContent("Plan", value: snapshot.planDisplayName)
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

            Section("Included usage") {
                poolRow("Cursor Models", systemImage: "sparkles", percent: snapshot.cursorModelsPercentUsed, tint: Color(red: 0.22, green: 0.48, blue: 0.86))
                poolRow("Other Models", systemImage: "cpu", percent: snapshot.otherModelsPercentUsed, tint: Color(red: 0.55, green: 0.35, blue: 0.82))
                poolRow("Total included", systemImage: "chart.pie.fill", percent: snapshot.totalPercentUsed, tint: Color(red: 0.20, green: 0.55, blue: 0.58))
            }

            Section("Plan") {
                if let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                    LabeledContent("Spend") {
                        Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                            .monospacedDigit()
                    }
                }
                if let bonus = snapshot.bonusCents, bonus > 0 {
                    LabeledContent("Bonus") {
                        Text("+\(MenuBarFormatter.usd(bonus))")
                            .monospacedDigit()
                    }
                }
                LabeledContent("On-demand") {
                    Text(onDemandLabel(snapshot))
                }
                if let used = snapshot.onDemandUsedCents {
                    LabeledContent("Billable") {
                        Text(MenuBarFormatter.usd(used))
                            .monospacedDigit()
                    }
                }
                if let days = snapshot.daysRemainingInCycle {
                    LabeledContent("Cycle") {
                        Text("\(days)d left")
                            .monospacedDigit()
                    }
                }
            }

            if !snapshot.modelBreakdown.isEmpty {
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

            Section {
                Text("Updated \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        ScrollView {
            VStack(spacing: 20) {
                AppLogo(size: 120)
                    .padding(.top, 36)
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var activeBinding: Binding<UUID> {
        Binding(
            get: { store.activeAccountID ?? store.connections.first?.id ?? UUID() },
            set: { store.setActive(id: $0) }
        )
    }

    private func poolRow(_ title: String, systemImage: String, percent: Double?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .foregroundStyle(tint)
                Spacer()
                Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(tint)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * min(1, max(0, (percent ?? 0) / 100)))
                }
            }
            .frame(height: 8)
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
