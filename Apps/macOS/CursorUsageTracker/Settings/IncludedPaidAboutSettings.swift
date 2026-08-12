import SwiftUI
import CursorUsageCore

struct IncludedUsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        ScrollView {
            Group {
                if let snapshot = store.snapshot {
                    VStack(alignment: .leading, spacing: 16) {
                        subscriptionHero(snapshot)
                        pools(snapshot)
                        models(snapshot)
                    }
                } else {
                    ContentUnavailableView(
                        "No usage yet",
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text("Sign in and refresh to see included usage.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func subscriptionHero(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(title: "Subscription", systemImage: "crown", subtitle: nil) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(snapshot.planDisplayName)
                            .font(.title2.weight(.bold))
                        if let status = snapshot.subscriptionStatus {
                            Text(status)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Color.green.opacity(0.15)))
                                .foregroundStyle(.green)
                        }
                    }
                    if let start = snapshot.billingCycleStart, let end = snapshot.billingCycleEnd {
                        Text("\(start.formatted(date: .abbreviated, time: .omitted)) → \(end.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let used = snapshot.planUsedCents {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(MenuBarFormatter.usd(used))
                            .font(.title3.monospacedDigit().weight(.semibold))
                        Text("period total")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if let days = snapshot.daysRemainingInCycle {
                    Text("\(days)d left")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(UsageAppearance.accentTotal.opacity(0.15)))
                        .foregroundStyle(UsageAppearance.accentTotal)
                }
            }
        }
    }

    private func pools(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(title: "Included pools", systemImage: "chart.bar.fill", subtitle: "Live percentages from Cursor.") {
            VStack(spacing: 14) {
                if let p = snapshot.cursorModelsPercentUsed {
                    IncludedPoolCard(
                        title: "Cursor Models",
                        systemImage: "sparkles",
                        percent: p,
                        caption: "First-party / Composer-style included usage",
                        accent: UsageAppearance.accentCursorModels
                    )
                }
                if let p = snapshot.otherModelsPercentUsed {
                    IncludedPoolCard(
                        title: "Other Models",
                        systemImage: "cpu",
                        percent: p,
                        caption: "API / third-party included usage",
                        accent: UsageAppearance.accentOtherModels
                    )
                }
                if let p = snapshot.totalPercentUsed {
                    IncludedPoolCard(
                        title: "Total included",
                        systemImage: "chart.pie.fill",
                        percent: p,
                        caption: "Overall included pool",
                        accent: UsageAppearance.accentTotal
                    )
                }
                if let bonus = snapshot.bonusCents, bonus > 0 {
                    HStack {
                        Label("Bonus credit", systemImage: "gift.fill")
                        Spacer()
                        Text(MenuBarFormatter.usd(bonus))
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundStyle(UsageAppearance.accentSpend)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(UsageAppearance.accentSpend.opacity(0.08)))
                }
            }
        }
    }

    private func models(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(title: "Models this period", systemImage: "list.bullet.rectangle", subtitle: nil) {
            if snapshot.modelBreakdown.isEmpty {
                Text("No model breakdown yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshot.modelBreakdown) { row in
                        HStack(spacing: 10) {
                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(UsageAppearance.accentOtherModels.opacity(0.7))
                            Text(row.model)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(MenuBarFormatter.usd(row.totalCents))
                                .font(.body.monospacedDigit())
                        }
                        .padding(.vertical, 2)
                    }
                    Divider()
                    if let total = snapshot.totalModelCostCents {
                        HStack {
                            Text("Total")
                                .fontWeight(.semibold)
                            Spacer()
                            Text(MenuBarFormatter.usd(total))
                                .font(.body.monospacedDigit().weight(.bold))
                        }
                    }
                }
            }
        }
    }
}

private struct IncludedPoolCard: View {
    let title: String
    let systemImage: String
    let percent: Double
    let caption: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(percent.rounded()))%")
                    .font(.title3.monospacedDigit().weight(.bold))
                    .foregroundStyle(UsageAppearance.color(forPool: title, percent: percent))
            }
            UsageProgressBar(percent: percent, tint: UsageAppearance.color(forPool: title, percent: percent))
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(accent.opacity(0.08))
        )
    }
}

struct PaidUsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        ScrollView {
            Group {
                if let snapshot = store.snapshot {
                    SettingsPanel(
                        title: "Usage-based pricing",
                        systemImage: "creditcard.fill",
                        subtitle: "On-demand spend beyond included pools."
                    ) {
                        HStack {
                            Label(
                                snapshot.onDemandEnabled ? "Enabled" : "Disabled",
                                systemImage: snapshot.onDemandEnabled ? "checkmark.circle.fill" : "xmark.octagon.fill"
                            )
                            .foregroundStyle(snapshot.onDemandEnabled ? Color.green : Color.red)
                            .font(.headline)
                            Spacer()
                        }
                        if let used = snapshot.onDemandUsedCents {
                            LabeledContent("Billable usage", value: MenuBarFormatter.usd(used))
                        }
                        LabeledContent(
                            "Current usage limit",
                            value: snapshot.onDemandLimitCents.map(MenuBarFormatter.usd)
                                ?? (snapshot.onDemandEnabled ? "—" : "$0")
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "No paid usage data",
                        systemImage: "creditcard",
                        description: Text("Sign in and refresh to see on-demand status.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct AboutSettingsView: View {
    var body: some View {
        ScrollView {
            SettingsPanel(title: "Cursor Usage Tracker", systemImage: "info.circle.fill", subtitle: nil) {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.10")
                Text("Personal open-source menu bar meter for Cursor Pro, Pro+, and Ultra. Unofficial session APIs may change; re-auth when needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
