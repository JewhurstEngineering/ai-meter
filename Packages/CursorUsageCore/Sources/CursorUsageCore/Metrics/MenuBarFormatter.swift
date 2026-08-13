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
            ? "Warning: a usage alert you set is active."
            : "Warning: \(why)."
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
        }

        if segments.isEmpty {
            segments = [.init(text: snapshot.planDisplayName)]
        }

        let hits = snapshot.menuBarWarningHits(preferences.menuBarWarnings)
        return .init(segments: segments, showWarningDot: !hits.isEmpty, warningHits: hits)
    }

    private enum Kind {
        case cursorModels, otherModels, total, spend, bonus, onDemand, days
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
