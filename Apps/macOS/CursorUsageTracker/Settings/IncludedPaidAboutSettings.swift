import SwiftUI
import CursorUsageCore

struct IncludedUsageSettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @Environment(\.appTheme) private var theme

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
                                .background(Capsule().fill(theme.ok.opacity(0.15)))
                                .foregroundStyle(theme.ok)
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
                        .background(Capsule().fill(theme.total.opacity(0.15)))
                        .foregroundStyle(theme.total)
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
                        accent: theme.cursorModels,
                        compact: true
                    )
                }
                if let p = snapshot.otherModelsPercentUsed {
                    IncludedPoolCard(
                        title: "Other Models",
                        systemImage: "cpu",
                        percent: p,
                        caption: "API / third-party",
                        accent: theme.otherModels,
                        compact: true
                    )
                }
                if let p = snapshot.totalPercentUsed {
                    IncludedPoolCard(
                        title: "Total included",
                        systemImage: "chart.pie.fill",
                        percent: p,
                        caption: "Overall pool",
                        accent: theme.total,
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
                        .foregroundStyle(theme.spend)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(theme.spend.opacity(0.08)))
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
                                .foregroundStyle(theme.otherModels.opacity(0.7))
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
    @Environment(\.appTheme) private var theme

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
                    .foregroundStyle(theme.color(forPool: title, percent: percent))
            }
            UsageProgressBar(
                percent: percent,
                tint: theme.color(forPool: title, percent: percent),
                pattern: .forPool(title)
            )
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        ScrollView {
            Group {
                if let snapshot = store.snapshot {
                    VStack(alignment: .leading, spacing: 10) {
                        status(snapshot)
                        meters(snapshot)
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
            .padding(12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func status(_ snapshot: UsageSnapshot) -> some View {
        let on = snapshot.onDemandEnabled
        return SettingsPanel(
            title: "On-demand",
            systemImage: "creditcard.fill",
            subtitle: on
                ? "Usage beyond included pools, billed at list price."
                : "Off — extra usage is not billed this way.",
            compact: true
        ) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(on ? "Enabled" : "Disabled")
                        .font(.headline)
                    if snapshot.isOnDemandUnlimited {
                        Text("No spend cap on this account.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let used = snapshot.onDemandUsedCents, let limit = snapshot.onDemandLimitCents, limit > 0 {
                        Text("\(MenuBarFormatter.usd(used)) of \(MenuBarFormatter.usd(limit)) billed this period")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if let used = snapshot.onDemandUsedCents {
                        Text("\(MenuBarFormatter.usd(used)) billed this period")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Text(on ? "On" : "Off")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill((on ? theme.ok : theme.danger).opacity(0.16)))
                    .foregroundStyle(on ? theme.ok : theme.danger)
            }
        }
    }

    private func meters(_ snapshot: UsageSnapshot) -> some View {
        let used = snapshot.onDemandUsedCents
        let limit = snapshot.onDemandLimitCents
        let percent: Double? = {
            guard let used, let limit, limit > 0 else { return nil }
            return min(100, Double(used) / Double(limit) * 100)
        }()

        return SettingsPanel(
            title: "This period",
            systemImage: "dollarsign.circle.fill",
            subtitle: "Billable on-demand vs the cap Cursor reports.",
            compact: true
        ) {
            HStack(alignment: .top, spacing: 8) {
                PaidStatCard(
                    title: "Billable usage",
                    systemImage: "creditcard",
                    value: used.map(MenuBarFormatter.usd) ?? "—",
                    caption: snapshot.onDemandEnabled ? "Beyond included pools" : "None while off",
                    accent: theme.spend,
                    percent: percent
                )
                PaidStatCard(
                    title: "Usage limit",
                    systemImage: "hand.raised.fill",
                    value: limitLabel(snapshot),
                    caption: limitCaption(snapshot, percent: percent),
                    accent: snapshot.onDemandEnabled ? theme.ok : theme.danger,
                    percent: snapshot.isOnDemandUnlimited ? nil : percent
                )
                if let planUsed = snapshot.planUsedCents, let planLimit = snapshot.planLimitCents {
                    PaidStatCard(
                        title: "Included plan",
                        systemImage: "dollarsign.circle",
                        value: "\(MenuBarFormatter.usd(planUsed))",
                        caption: "of \(MenuBarFormatter.usd(planLimit)) base",
                        accent: theme.total,
                        percent: planLimit > 0 ? min(100, Double(planUsed) / Double(planLimit) * 100) : nil
                    )
                }
            }
        }
    }

    private func limitLabel(_ snapshot: UsageSnapshot) -> String {
        if snapshot.isOnDemandUnlimited { return "Unlimited" }
        if let limit = snapshot.onDemandLimitCents { return MenuBarFormatter.usd(limit) }
        return snapshot.onDemandEnabled ? "—" : "$0"
    }

    private func limitCaption(_ snapshot: UsageSnapshot, percent: Double?) -> String {
        if snapshot.isOnDemandUnlimited { return "No cap" }
        if let percent {
            return "\(Int(percent.rounded()))% of cap"
        }
        if !snapshot.onDemandEnabled { return "On-demand off" }
        return "Cap from Cursor"
    }
}

private struct PaidStatCard: View {
    let title: String
    let systemImage: String
    let value: String
    let caption: String
    let accent: Color
    var percent: Double? = nil
    @Environment(\.appTheme) private var theme
    @Environment(\.appHighContrast) private var highContrast

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let percent {
                UsageProgressBar(percent: percent, tint: accent, pattern: .dashes)
                    .frame(height: 6)
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accent.opacity(highContrast ? 0.22 : 0.16))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(accent.opacity(highContrast ? 0.55 : 0.35), lineWidth: 1)
        )
    }
}

struct AboutSettingsView: View {
    @Environment(\.appTheme) private var theme
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.8"
    }

    @State private var installMessage: String?
    @State private var installSucceeded = false

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
                        subtitle: "Gallery presets for Cursor, Other, Total, On-demand, and Rotate. Overview is small, medium, and large.",
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
                                    do {
                                        let dest = try AppInstall.copyRunningAppToApplications()
                                        installSucceeded = true
                                        installMessage = "Copied to \(dest.path). Keep this Settings window. Then quit the Xcode copy and open the Applications app."
                                    } catch {
                                        installSucceeded = false
                                        installMessage = "Couldn’t install: \(error.localizedDescription)"
                                    }
                                    AppActivation.scheduleSettingsFocus()
                                } label: {
                                    Label("Install to Applications", systemImage: "square.and.arrow.down")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }

                            if installSucceeded, !isRunningFromApplications {
                                HStack(spacing: 8) {
                                    Button("Reveal in Finder") {
                                        NSWorkspace.shared.activateFileViewerSelecting([AppInstall.installedAppURL])
                                        AppActivation.scheduleSettingsFocus()
                                    }
                                    .controlSize(.small)
                                    Button("Quit this copy & open installed app") {
                                        AppInstall.launchInstalledAndTerminate()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }

                            aboutBullet("1.circle", "Install (button above) — does not launch a second copy")
                            aboutBullet("2.circle", "Quit this Xcode build, then open Applications ▸ Cursor Usage Tracker")
                            aboutBullet("3.circle", "Right-click desktop → Edit Widgets → Cursor Usage presets. Re-add after this update.")

                            if let installMessage {
                                Text(installMessage)
                                    .font(.caption2)
                                    .foregroundStyle(installSucceeded ? Color.secondary : Color.orange)
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

    private var hero: some View {
        HStack(alignment: .center, spacing: 14) {
            AppLogo(size: 56)
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
                        .background(Capsule().fill(theme.cursorModels.opacity(0.15)))
                        .foregroundStyle(theme.cursorModels)
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
