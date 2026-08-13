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
        let base = body.isEmpty ? "Cursor Usage" : body
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
        guard authenticated else {
            return .init(segments: [.init(systemImage: "person.crop.circle.badge.questionmark", text: "Sign in")], showWarningDot: false)
        }
        guard let snapshot else {
            return .init(segments: [.init(text: "…")], showWarningDot: false)
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
        if entries.isEmpty || entries.allSatisfy({ !$0.authenticated }) {
            return .init(
                segments: [.init(systemImage: "person.crop.circle.badge.questionmark", text: "Sign in")],
                showWarningDot: false
            )
        }

        var segments: [MenuBarSegment] = []
        var hits: [UsageSnapshot.MenuBarWarningHit] = []

        for entry in entries {
            if !entry.authenticated {
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
        if toggles.otherModelsPercent, let p = snapshot.otherModelsPercentUsed { return pct(p) }
        if toggles.cursorModelsPercent, let p = snapshot.cursorModelsPercentUsed { return pct(p) }
        if toggles.totalPercent, let p = snapshot.totalPercentUsed { return pct(p) }
        if toggles.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
            return "\(usd(used))/\(usd(limit))"
        }
        if toggles.burnRateEstimate, let today = snapshot.todaySpendCents {
            return usd(today)
        }
        return snapshot.planDisplayName
    }

    private static func metricSegments(snapshot: UsageSnapshot, preferences: DisplayPreferences) -> [MenuBarSegment] {
        let toggles = preferences.menuBar
        let style = preferences.menuBarLabelStyle
        var segments: [MenuBarSegment] = []

        switch preferences.menuBarFormat {
        case .compact:
            if toggles.otherModelsPercent, let p = snapshot.otherModelsPercentUsed {
                segments.append(segment(style: style, kind: .otherModels, text: pct(p)))
            } else if toggles.cursorModelsPercent, let p = snapshot.cursorModelsPercentUsed {
                segments.append(segment(style: style, kind: .cursorModels, text: pct(p)))
            } else if toggles.totalPercent, let p = snapshot.totalPercentUsed {
                segments.append(segment(style: style, kind: .total, text: pct(p)))
            } else if toggles.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                segments.append(segment(style: style, kind: .spend, text: "\(usd(used))/\(usd(limit))"))
            } else if toggles.burnRateEstimate, let today = snapshot.todaySpendCents {
                segments.append(segment(style: style, kind: .today, text: usd(today)))
            }
        case .detailed:
            if toggles.cursorModelsPercent, let p = snapshot.cursorModelsPercentUsed {
                segments.append(segment(style: style, kind: .cursorModels, text: labeled(style, kind: .cursorModels, value: pct(p))))
            }
            if toggles.otherModelsPercent, let p = snapshot.otherModelsPercentUsed {
                segments.append(segment(style: style, kind: .otherModels, text: labeled(style, kind: .otherModels, value: pct(p))))
            }
            if toggles.totalPercent, let p = snapshot.totalPercentUsed {
                segments.append(segment(style: style, kind: .total, text: labeled(style, kind: .total, value: pct(p))))
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
            }
            if toggles.daysRemaining, let days = snapshot.daysRemainingInCycle {
                segments.append(segment(style: style, kind: .days, text: "\(days)d"))
            }
            if toggles.burnRateEstimate, let today = snapshot.todaySpendCents {
                segments.append(segment(style: style, kind: .today, text: labeled(style, kind: .today, value: usd(today))))
            }
        }
        return segments
    }

    private enum Kind {
        case cursorModels, otherModels, total, spend, bonus, onDemand, days, today
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
            case .onDemand: return "On-demand \(value)"
            case .today: return "Today \(value)"
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
        case (.icons, .spend): icon = "dollarsign.circle"
        case (.icons, .bonus): icon = "gift"
        case (.icons, .onDemand): icon = "creditcard"
        case (.icons, .days): icon = "calendar"
        case (.icons, .today): icon = "chart.line.uptrend.xyaxis"
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
}
