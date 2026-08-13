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

            ScrollView {
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
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .frame(width: 360, height: 580)
        // Flatten to an opaque bitmap so popover vibrancy cannot bleed editor content through.
        .background(Color(nsColor: .windowBackgroundColor))
        .compositingGroup()
        .appThemed(store.preferences)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            AppLogo(size: 34)
            VStack(alignment: .leading, spacing: 5) {
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
                if store.menuBarPresentation.showWarningDot {
                    headerAlarms(store.menuBarPresentation.warningHits)
                }
            }
            Spacer(minLength: 8)
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

    private func headerAlarms(_ hits: [UsageSnapshot.MenuBarWarningHit]) -> some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(hits.enumerated()), id: \.element.id) { index, hit in
                    if index > 0 {
                        Text("·")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.danger.opacity(0.4))
                            .padding(.horizontal, 4)
                    }
                    alarmReadout(hit)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.danger.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(theme.danger.opacity(0.38), lineWidth: 1)
            )

            Button("Clear") {
                store.snoozeAllMenuBarWarnings()
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
            .help("Hide until usage drops back under the alert. Does not change the threshold.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Usage alarms")
        .accessibilityValue(hits.map(\.compactLine).joined(separator: ", "))
    }

    private func alarmReadout(_ hit: UsageSnapshot.MenuBarWarningHit) -> some View {
        HStack(spacing: 5) {
            Button {
                AppActivation.openSettingsViaLinkFallback()
            } label: {
                HStack(spacing: 5) {
                    Circle()
                        .fill(theme.danger)
                        .frame(width: 6, height: 6)
                        .shadow(color: theme.danger.opacity(0.75), radius: 3)
                    Text(hit.channel.shortTitle.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.6)
                    Text(hit.current)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("@")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(hit.threshold)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(theme.danger)
            }
            .buttonStyle(.plain)
            .help("\(hit.sentence). Click to change the alert in Settings → General.")

            Button {
                store.snoozeMenuBarWarning(hit.channel)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(theme.danger.opacity(0.7))
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Clear \(hit.channel.shortTitle) until it drops back under \(hit.threshold).")
        }
    }

    @ViewBuilder
    private func usageBody(_ snapshot: UsageSnapshot) -> some View {
        let t = store.preferences.popover

        VStack(alignment: .leading, spacing: 12) {
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
