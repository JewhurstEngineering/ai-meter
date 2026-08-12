import SwiftUI
import AppKit
import CursorUsageCore

struct MenuBarPopoverView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            if !store.isAuthenticated {
                signInPrompt
            } else if let snapshot = store.snapshot {
                usageBody(snapshot)
            } else if store.isRefreshing {
                ProgressView("Loading usage…")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                Text(store.lastError ?? "No usage data yet.")
                    .foregroundStyle(.secondary)
            }
            Divider()
            footer
        }
        .padding(14)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Subscription: \(store.snapshot?.planDisplayName ?? "—")")
                    .font(.headline)
                if let fetched = store.snapshot?.fetchedAt {
                    Text("Updated: \(fetched.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Refresh") {
                Task { await store.refresh() }
            }
            .disabled(store.isRefreshing || !store.isAuthenticated)
        }
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not signed in")
                .font(.subheadline.weight(.semibold))
            Text("Connect via Settings → Authentication (Web login, local Cursor session, or paste token).")
                .font(.caption)
                .foregroundStyle(.secondary)
            SettingsLink {
                Label("Open Settings", systemImage: "gear")
            }
        }
    }

    @ViewBuilder
    private func usageBody(_ snapshot: UsageSnapshot) -> some View {
        let t = store.preferences.popover

        if t.cursorModelsPercent || t.otherModelsPercent || t.totalPercent {
            Text("Included Usage")
                .font(.subheadline.weight(.semibold))
            if t.cursorModelsPercent, let p = snapshot.cursorModelsPercentUsed {
                PoolRow(title: "Cursor Models", percent: p, detail: snapshot.displayMessages.cursorModels)
            }
            if t.otherModelsPercent, let p = snapshot.otherModelsPercentUsed {
                PoolRow(title: "Other Models", percent: p, detail: snapshot.displayMessages.otherModels)
            }
            if t.totalPercent, let p = snapshot.totalPercentUsed {
                PoolRow(title: "Total included", percent: p, detail: nil)
            }
        }

        if t.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
            Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit)) base")
                .font(.caption)
                .foregroundStyle(.secondary)
            if t.bonus, let bonus = snapshot.bonusCents, bonus > 0 {
                Text("+\(MenuBarFormatter.usd(bonus)) bonus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }

        if t.onDemand {
            HStack {
                Text("On-Demand")
                Spacer()
                Text(snapshot.onDemandEnabled ? "Enabled" : "Disabled")
                    .foregroundStyle(snapshot.onDemandEnabled ? Color.primary : Color.red)
                    .fontWeight(.semibold)
            }
            .font(.caption)
        }

        if t.daysRemaining, let end = snapshot.billingCycleEnd, let days = snapshot.daysRemainingInCycle {
            Text("Ends \(end.formatted(date: .abbreviated, time: .shortened)) (\(days) days left)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let error = store.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",", modifiers: .command)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .font(.caption)
    }
}

private struct PoolRow: View {
    let title: String
    let percent: Double
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(percent.rounded()))% used")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
            ProgressView(value: min(max(percent / 100.0, 0), 1))
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
