import Foundation

public struct MenuBarSegment: Sendable, Equatable {
    public var systemImage: String?
    public var text: String

    public init(systemImage: String? = nil, text: String) {
        self.systemImage = systemImage
        self.text = text
    }
}

public struct MenuBarPresentation: Sendable, Equatable {
    public var segments: [MenuBarSegment]
    public var showWarningDot: Bool
    public var warningHits: [UsageSnapshot.MenuBarWarningHit]

    public var accessibilityTitle: String {
        let body = segments.map(\.text).joined(separator: " · ")
        let base = body.isEmpty ? "AI Meter" : body
        guard showWarningDot else { return base }
        let why = warningHits.map(\.sentence).joined(separator: ". ")
        let reason = why.isEmpty
            ? "Red dot: a usage alert you set is active."
            : "Red dot: \(why)."
        return "\(base)\n\(reason)\nChange alert levels in Settings → General."
    }

    public init(
        segments: [MenuBarSegment],
        showWarningDot: Bool,
        warningHits: [UsageSnapshot.MenuBarWarningHit] = []
    ) {
        self.segments = segments
        self.showWarningDot = showWarningDot
        self.warningHits = warningHits
    }
}

public enum MenuBarFormatter {
    public static func format(
        snapshot: UsageSnapshot?,
        preferences: DisplayPreferences,
        authenticated: Bool
    ) -> MenuBarPresentation {
        guard let snapshot else {
            if authenticated {
                return .init(segments: [.init(text: "…")], showWarningDot: false)
            }
            return .init(segments: [.init(systemImage: "person.crop.circle.badge.questionmark", text: "Sign in")], showWarningDot: false)
        }

        var segments = metricSegments(snapshot: snapshot, preferences: preferences)

        if segments.isEmpty {
            segments = [.init(text: snapshot.planDisplayName)]
        }

        let hits = snapshot.menuBarWarningHits(preferences.menuBarWarnings)
            .filter { !preferences.snoozedWarningChannels.contains($0.channel.rawValue) }
        return .init(segments: segments, showWarningDot: !hits.isEmpty, warningHits: hits)
    }

    /// Stacked menu bar: `work 12% · personal 88%` using each account's headline metric.
    public static func formatCombined(
        entries: [(label: String, snapshot: UsageSnapshot?, authenticated: Bool)],
        preferences: DisplayPreferences
    ) -> MenuBarPresentation {
        if entries.isEmpty || entries.allSatisfy({ !$0.authenticated && $0.snapshot == nil }) {
            return .init(
                segments: [.init(systemImage: "person.crop.circle.badge.questionmark", text: "Sign in")],
                showWarningDot: false
            )
        }

        var segments: [MenuBarSegment] = []
        var hits: [UsageSnapshot.MenuBarWarningHit] = []

        for entry in entries {
            if !entry.authenticated, entry.snapshot == nil {
                segments.append(.init(text: "\(entry.label) Sign in"))
                continue
            }
            guard let snapshot = entry.snapshot else {
                segments.append(.init(text: "\(entry.label) …"))
                continue
            }
            let metric = headlineMetric(snapshot: snapshot, preferences: preferences)
            segments.append(.init(text: "\(entry.label) \(metric)"))
            hits.append(contentsOf: snapshot.menuBarWarningHits(preferences.menuBarWarnings).filter {
                !preferences.snoozedWarningChannels.contains($0.channel.rawValue)
            })
        }

        return .init(segments: segments, showWarningDot: !hits.isEmpty, warningHits: hits)
    }

    private static func headlineMetric(snapshot: UsageSnapshot, preferences: DisplayPreferences) -> String {
        let toggles = preferences.menuBar
        let windows = snapshot.effectiveWindows
        if let window = preferredHeadlineWindow(windows, toggles: toggles) {
            return pct(window.percentUsed)
        }
        if toggles.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
            return "\(usd(used))/\(usd(limit))"
        }
        if let spend = snapshot.spend, toggles.onDemand, let remaining = spend.remainingCents {
            return usd(remaining)
        }
        if toggles.burnRateEstimate, let pace = snapshot.pace() {
            return pace.menuBarText
        }
        return snapshot.planDisplayName
    }

    private static func preferredHeadlineWindow(
        _ windows: [QuotaWindow],
        toggles: DisplayPreferences.SurfaceToggles
    ) -> QuotaWindow? {
        let order: [(QuotaWindowRole, Bool)] = [
            (.otherModels, toggles.otherModelsPercent),
            (.weekly, toggles.weeklyPercent),
            (.cursorModels, toggles.cursorModelsPercent),
            (.session, toggles.sessionPercent),
            (.totalIncluded, toggles.totalPercent),
        ]
        for (role, enabled) in order where enabled {
            if let window = windows.first(where: { $0.role == role }) { return window }
        }
        return windows.first
    }

    private static func metricSegments(snapshot: UsageSnapshot, preferences: DisplayPreferences) -> [MenuBarSegment] {
        let toggles = preferences.menuBar
        let style = preferences.menuBarLabelStyle
        var segments: [MenuBarSegment] = []
        let windows = snapshot.effectiveWindows

        func appendWindow(_ role: QuotaWindowRole, enabled: Bool, kind: Kind) {
            guard enabled, let window = windows.first(where: { $0.role == role }) else { return }
            let value = pct(window.percentUsed)
            segments.append(segment(style: style, kind: kind, text: labeled(style, kind: kind, value: value)))
        }

        switch preferences.menuBarFormat {
        case .compact:
            if let window = preferredHeadlineWindow(windows, toggles: toggles) {
                let kind = kind(for: window.role)
                segments.append(segment(style: style, kind: kind, text: pct(window.percentUsed)))
            } else if toggles.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                segments.append(segment(style: style, kind: .spend, text: "\(usd(used))/\(usd(limit))"))
            } else if toggles.burnRateEstimate, let pace = snapshot.pace() {
                segments.append(segment(style: style, kind: .pace, text: pace.menuBarText))
            }
        case .detailed:
            appendWindow(.cursorModels, enabled: toggles.cursorModelsPercent, kind: .cursorModels)
            appendWindow(.otherModels, enabled: toggles.otherModelsPercent, kind: .otherModels)
            appendWindow(.totalIncluded, enabled: toggles.totalPercent, kind: .total)
            appendWindow(.session, enabled: toggles.sessionPercent, kind: .session)
            appendWindow(.weekly, enabled: toggles.weeklyPercent, kind: .weekly)
            for extra in windows where extra.role == .extra {
                segments.append(segment(style: style, kind: .extra, text: labeled(style, kind: .extra, value: "\(extra.title) \(pct(extra.percentUsed))")))
            }
            if toggles.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                var spend = "\(usd(used))/\(usd(limit))"
                if toggles.bonus, let bonus = snapshot.bonusCents, bonus > 0 {
                    spend += " +\(usd(bonus))"
                }
                segments.append(segment(style: style, kind: .spend, text: spend))
            } else if toggles.bonus, let bonus = snapshot.bonusCents, bonus > 0 {
                segments.append(segment(style: style, kind: .bonus, text: "+\(usd(bonus))"))
            }
            if toggles.onDemand {
                if snapshot.provider == .cursor {
                    let value: String
                    if snapshot.onDemandEnabled {
                        if let used = snapshot.onDemandUsedCents {
                            value = usd(used)
                        } else {
                            value = "on"
                        }
                    } else {
                        value = "off"
                    }
                    segments.append(segment(style: style, kind: .onDemand, text: labeled(style, kind: .onDemand, value: value)))
                } else if let spend = snapshot.spend {
                    let value: String
                    if spend.unlimited {
                        value = "∞"
                    } else if let remaining = spend.remainingCents {
                        value = usd(remaining)
                    } else if let used = spend.usedCents {
                        value = usd(used)
                    } else {
                        value = spend.enabled ? "on" : "off"
                    }
                    segments.append(segment(style: style, kind: .onDemand, text: labeled(style, kind: .credits, value: value)))
                }
            }
            if toggles.daysRemaining {
                if snapshot.provider == .cursor, let days = snapshot.daysRemainingInCycle {
                    segments.append(segment(style: style, kind: .days, text: "\(days)d"))
                } else if let reset = snapshot.nextResetAt {
                    segments.append(segment(style: style, kind: .days, text: relative(reset)))
                }
            }
            if toggles.burnRateEstimate, snapshot.provider == .cursor, let pace = snapshot.pace() {
                segments.append(segment(style: style, kind: .pace, text: labeled(style, kind: .pace, value: pace.menuBarText)))
            }
        }
        return segments
    }

    private enum Kind {
        case cursorModels, otherModels, total, session, weekly, extra, spend, bonus, onDemand, credits, days, pace
    }

    private static func kind(for role: QuotaWindowRole) -> Kind {
        switch role {
        case .cursorModels: return .cursorModels
        case .otherModels: return .otherModels
        case .totalIncluded: return .total
        case .session: return .session
        case .weekly: return .weekly
        case .extra: return .extra
        }
    }

    private static func pct(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private static func labeled(_ style: DisplayPreferences.MenuBarLabelStyle, kind: Kind, value: String) -> String {
        switch style {
        case .icons:
            // Icon carries meaning; keep text short.
            return value
        case .shortWords:
            switch kind {
            case .cursorModels: return "Cursor \(value)"
            case .otherModels: return "Other \(value)"
            case .total: return "Total \(value)"
            case .session: return "Session \(value)"
            case .weekly: return "Weekly \(value)"
            case .extra: return value
            case .onDemand: return "On-demand \(value)"
            case .credits: return "Credits \(value)"
            case .pace: return "Pace \(value)"
            case .spend, .bonus, .days: return value
            }
        }
    }

    private static func segment(style: DisplayPreferences.MenuBarLabelStyle, kind: Kind, text: String) -> MenuBarSegment {
        let icon: String?
        switch (style, kind) {
        case (.icons, .cursorModels): icon = "sparkles"
        case (.icons, .otherModels): icon = "cpu"
        case (.icons, .total): icon = "chart.pie"
        case (.icons, .session): icon = "clock"
        case (.icons, .weekly): icon = "calendar"
        case (.icons, .extra): icon = "square.grid.2x2"
        case (.icons, .spend): icon = "dollarsign.circle"
        case (.icons, .bonus): icon = "gift"
        case (.icons, .onDemand): icon = "creditcard"
        case (.icons, .credits): icon = "bitcoinsign.circle"
        case (.icons, .days): icon = "calendar"
        case (.icons, .pace): icon = "speedometer"
        case (.shortWords, _): icon = nil
        }
        return .init(systemImage: icon, text: text)
    }

    public static func usd(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        if dollars == floor(dollars) {
            return String(format: "$%.0f", dollars)
        }
        return String(format: "$%.2f", dollars)
    }

    public static func usd(_ cents: Double) -> String {
        usd(Int(cents.rounded()))
    }

    public static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    public static func compactCount(_ n: Int) -> String {
        let absN = abs(n)
        if absN >= 1_000_000 {
            let value = Double(n) / 1_000_000
            return formatCompact(value, suffix: "M")
        }
        if absN >= 1_000 {
            let value = Double(n) / 1_000
            return formatCompact(value, suffix: "K")
        }
        return "\(n)"
    }

    public static func tokenCaption(input: Int?, output: Int?) -> String? {
        guard input != nil || output != nil else { return nil }
        var parts: [String] = []
        if let input {
            parts.append("\(compactCount(input)) in")
        }
        if let output {
            parts.append("\(compactCount(output)) out")
        }
        return parts.joined(separator: " · ")
    }

    public static func tokenCaption(_ cost: UsageSnapshot.ModelCost) -> String? {
        tokenCaption(input: cost.inputTokens, output: cost.outputTokens)
    }

    private static func formatCompact(_ value: Double, suffix: String) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == floor(rounded) {
            return String(format: "%.0f%@", rounded, suffix)
        }
        return String(format: "%.1f%@", rounded, suffix)
    }
}
