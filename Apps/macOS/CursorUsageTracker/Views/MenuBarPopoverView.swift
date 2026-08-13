import SwiftUI
import AppKit
import CursorUsageCore

struct MenuBarPopoverView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider()

            Group {
                if !store.isAuthenticated {
                    signInPrompt
                } else if let snapshot = store.snapshot {
                    usageBody(snapshot)
                } else if store.isRefreshing {
                    ProgressView("Loading usage…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 28)
                } else {
                    Text(store.lastError ?? "No usage data yet.")
                        .foregroundStyle(.secondary)
                        .padding(14)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: 360)
        .fixedSize(horizontal: true, vertical: true)
        // Flatten to an opaque bitmap so popover vibrancy cannot bleed editor content through.
        .background(Color(nsColor: .windowBackgroundColor))
        .compositingGroup()
        .appThemed(store.preferences)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            AppLogo(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.snapshot?.planDisplayName ?? "Cursor")
                    .font(.headline)
                if let fetched = store.snapshot?.fetchedAt {
                    Text("Updated \(fetched.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Subscription")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .disabled(store.isRefreshing || !store.isAuthenticated)
            .help("Refresh")
        }
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Not signed in", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.subheadline.weight(.semibold))
            Text("Open Settings → Authentication to connect with Cursor, local session, or a pasted token.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SettingsOpenLink {
                Label("Open Settings", systemImage: "gearshape")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func warningBanner(_ hits: [UsageSnapshot.MenuBarWarningHit]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline)
                Text("Menu bar warning")
                    .font(.subheadline.weight(.semibold))
            }
            if hits.isEmpty {
                Text("A usage alert you set is active.")
                    .font(.caption)
            } else {
                ForEach(hits) { hit in
                    Text(hit.sentence)
                        .font(.caption)
                }
            }
            Text("That’s the warning icon next to the menu bar meter — not an error. Change levels in Settings → General.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.40), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Menu bar warning")
        .accessibilityValue(hits.map(\.sentence).joined(separator: ". "))
    }

    @ViewBuilder
    private func usageBody(_ snapshot: UsageSnapshot) -> some View {
        let t = store.preferences.popover

        VStack(alignment: .leading, spacing: 12) {
            if store.menuBarPresentation.showWarningDot {
                warningBanner(store.menuBarPresentation.warningHits)
            }

            if t.cursorModelsPercent || t.otherModelsPercent || t.totalPercent {
                Text("Included usage")
                    .font(.caption.weight(.semibold))
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

            if t.planSpend || t.bonus || t.onDemand || t.daysRemaining {
                VStack(alignment: .leading, spacing: 8) {
                    if t.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                        Label {
                            HStack {
                                Text("\(MenuBarFormatter.usd(used)) / \(MenuBarFormatter.usd(limit))")
                                    .font(.subheadline.monospacedDigit().weight(.semibold))
                                Text("base")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundStyle(theme.spend)
                        }
                        if t.bonus, let bonus = snapshot.bonusCents, bonus > 0 {
                            Label("+\(MenuBarFormatter.usd(bonus)) bonus", systemImage: "gift.fill")
                                .font(.caption)
                                .foregroundStyle(theme.spend)
                        }
                    }

                    if t.onDemand {
                        HStack {
                            Label("On-demand", systemImage: "creditcard.fill")
                            Spacer()
                            Text(snapshot.onDemandEnabled ? "Enabled" : "Disabled")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(
                                        (snapshot.onDemandEnabled ? theme.ok : theme.danger).opacity(0.18)
                                    )
                                )
                                .foregroundStyle(snapshot.onDemandEnabled ? theme.ok : theme.danger)
                        }
                        .font(.subheadline)
                    }

                    if t.daysRemaining, let end = snapshot.billingCycleEnd, let days = snapshot.daysRemainingInCycle {
                        Label(
                            "Ends \(end.formatted(date: .abbreviated, time: .shortened)) · \(days)d left",
                            systemImage: "calendar"
                        )
                        .font(.caption)
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

            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var footer: some View {
        HStack {
            SettingsOpenLink {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.small)
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
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(percent.rounded()))%")
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(tint)
            }
            UsageProgressBar(percent: percent, tint: tint, pattern: .forPool(title))
            if let caption {
                Text(caption)
                    .font(.caption2)
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if rows.isEmpty {
                Text("No model spend yet this period.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.caption)
                                .foregroundStyle(theme.otherModels.opacity(0.75))
                            Text(row.model)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 8)
                            Text(MenuBarFormatter.usd(row.totalCents))
                                .font(.caption.monospacedDigit().weight(.medium))
                        }
                    }

                    if overflow > 0 {
                        Text("+\(overflow) more in Settings → Included")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let total = snapshot.totalModelCostCents {
                        Divider()
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
