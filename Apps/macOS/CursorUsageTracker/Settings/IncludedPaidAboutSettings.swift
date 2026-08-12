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
                .fill(accent.opacity(0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .strokeBorder(accent.opacity(0.35), lineWidth: 1)
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
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.18"
    }

    @State private var installMessage: String?

    private var isRunningFromApplications: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                hero

                HStack(alignment: .top, spacing: 10) {
                    SettingsPanel(
                        title: "What it tracks",
                        systemImage: "chart.bar.fill",
                        subtitle: "Personal Pro / Pro+ / Ultra.",
                        compact: true
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            aboutBullet("sparkles", "Cursor Models included pool")
                            aboutBullet("cpu", "Other Models included pool")
                            aboutBullet("creditcard", "On-demand, limits, and spend")
                            aboutBullet("bell.badge", "Menu bar warnings + notifications")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    SettingsPanel(
                        title: "Desktop widget",
                        systemImage: "rectangle.on.rectangle",
                        subtitle: "macOS only lists widgets from /Applications.",
                        compact: true
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Xcode Run copies live in DerivedData, so Edit Widgets search stays empty until the app is installed.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if isRunningFromApplications {
                                Label("Installed in Applications — search “Cursor Usage”.", systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Button {
                                    installMessage = installToApplications()
                                } label: {
                                    Label("Install to Applications", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }

                            aboutBullet("1.circle", "Install (button above) or drag this .app into /Applications")
                            aboutBullet("2.circle", "Open that copy once from Applications")
                            aboutBullet("3.circle", "Right-click desktop → Edit Widgets → “Cursor Usage”")

                            if let installMessage {
                                Text(installMessage)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }

                SettingsPanel(
                    title: "Unofficial & local-first",
                    systemImage: "lock.shield",
                    subtitle: nil,
                    compact: true
                ) {
                    Text("Session tokens stay in Keychain on this Mac. Widgets only see a sanitized usage snapshot — never credentials. Cursor’s personal APIs can change; re-auth from Authentication if usage stops updating.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Link(destination: URL(string: "https://cursor.com/dashboard")!) {
                            Label("Cursor dashboard", systemImage: "globe")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        Spacer()
                        Text("MIT license · open source")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func installToApplications() -> String {
        let src = Bundle.main.bundleURL
        let dest = URL(fileURLWithPath: "/Applications/Cursor Usage Tracker.app")
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: src, to: dest)
            NSWorkspace.shared.open(dest)
            return "Copied to \(dest.path). Quit the Xcode copy, use the Applications one, then Edit Widgets."
        } catch {
            return "Couldn’t install: \(error.localizedDescription). Drag the app into /Applications yourself."
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                UsageAppearance.accentCursorModels,
                                UsageAppearance.accentOtherModels,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title)
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Cursor Usage Tracker")
                    .font(.title2.weight(.bold))
                Text("Menu bar meter for Cursor usage — unofficial, local-first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text("v\(version)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(UsageAppearance.accentCursorModels.opacity(0.15)))
                        .foregroundStyle(UsageAppearance.accentCursorModels)
                    Text("macOS 14+")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func aboutBullet(_ systemImage: String, _ text: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .labelStyle(.titleAndIcon)
    }
}
