import SwiftUI
import CursorUsageCore

struct IncludedUsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        ScrollView {
            Group {
                if let snapshot = store.snapshot {
                    VStack(alignment: .leading, spacing: 10) {
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
                    .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
                                .background(Capsule().fill(Color.green.opacity(0.15)))
                                .foregroundStyle(.green)
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
                        .background(Capsule().fill(UsageAppearance.accentTotal.opacity(0.15)))
                        .foregroundStyle(UsageAppearance.accentTotal)
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
                        accent: UsageAppearance.accentCursorModels,
                        compact: true
                    )
                }
                if let p = snapshot.otherModelsPercentUsed {
                    IncludedPoolCard(
                        title: "Other Models",
                        systemImage: "cpu",
                        percent: p,
                        caption: "API / third-party",
                        accent: UsageAppearance.accentOtherModels,
                        compact: true
                    )
                }
                if let p = snapshot.totalPercentUsed {
                    IncludedPoolCard(
                        title: "Total included",
                        systemImage: "chart.pie.fill",
                        percent: p,
                        caption: "Overall pool",
                        accent: UsageAppearance.accentTotal,
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
                        .foregroundStyle(UsageAppearance.accentSpend)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(UsageAppearance.accentSpend.opacity(0.08)))
            }
        }
    }

    private func models(_ snapshot: UsageSnapshot) -> some View {
        SettingsPanel(title: "Models this period", systemImage: "list.bullet.rectangle", subtitle: nil, compact: true) {
            if snapshot.modelBreakdown.isEmpty {
                Text("No model breakdown yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    ForEach(snapshot.modelBreakdown) { row in
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(UsageAppearance.accentOtherModels.opacity(0.7))
                            Text(row.model)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Text(MenuBarFormatter.usd(row.totalCents))
                                .font(.caption.monospacedDigit())
                        }
                    }
                    Divider().padding(.vertical, 2)
                    if let total = snapshot.totalModelCostCents {
                        HStack {
                            Text("Total")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(MenuBarFormatter.usd(total))
                                .font(.caption.monospacedDigit().weight(.bold))
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
    var compact: Bool = false

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
                    .foregroundStyle(UsageAppearance.color(forPool: title, percent: percent))
            }
            UsageProgressBar(percent: percent, tint: UsageAppearance.color(forPool: title, percent: percent))
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
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.14")
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
