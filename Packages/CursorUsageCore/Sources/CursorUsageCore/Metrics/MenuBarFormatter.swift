import Foundation

public struct MenuBarPresentation: Sendable, Equatable {
    public var title: String
    public var showWarningDot: Bool
}

public enum MenuBarFormatter {
    public static func format(
        snapshot: UsageSnapshot?,
        preferences: DisplayPreferences,
        authenticated: Bool
    ) -> MenuBarPresentation {
        guard authenticated else {
            return .init(title: "Cursor · Sign in", showWarningDot: false)
        }
        guard let snapshot else {
            return .init(title: "Cursor · …", showWarningDot: false)
        }

        let toggles = preferences.menuBar
        var parts: [String] = []

        switch preferences.menuBarFormat {
        case .compact:
            if toggles.otherModelsPercent, let p = snapshot.otherModelsPercentUsed {
                parts.append(String(format: "%.0f%%", p))
            } else if toggles.cursorModelsPercent, let p = snapshot.cursorModelsPercentUsed {
                parts.append(String(format: "%.0f%%", p))
            } else if toggles.totalPercent, let p = snapshot.totalPercentUsed {
                parts.append(String(format: "%.0f%%", p))
            } else if toggles.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                parts.append("\(usd(used))/\(usd(limit))")
            }
        case .detailed:
            if toggles.cursorModelsPercent, let p = snapshot.cursorModelsPercentUsed {
                parts.append(String(format: "CM %.0f%%", p))
            }
            if toggles.otherModelsPercent, let p = snapshot.otherModelsPercentUsed {
                parts.append(String(format: "OM %.0f%%", p))
            }
            if toggles.totalPercent, let p = snapshot.totalPercentUsed {
                parts.append(String(format: "Tot %.0f%%", p))
            }
            if toggles.planSpend, let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents {
                var spend = "\(usd(used))/\(usd(limit))"
                if toggles.bonus, let bonus = snapshot.bonusCents, bonus > 0 {
                    spend += " +\(usd(bonus))"
                }
                parts.append(spend)
            } else if toggles.bonus, let bonus = snapshot.bonusCents, bonus > 0 {
                parts.append("+\(usd(bonus))")
            }
            if toggles.onDemand {
                if snapshot.onDemandEnabled {
                    if let used = snapshot.onDemandUsedCents {
                        parts.append("OD \(usd(used))")
                    } else {
                        parts.append("OD on")
                    }
                } else {
                    parts.append("OD off")
                }
            }
            if toggles.daysRemaining, let days = snapshot.daysRemainingInCycle {
                parts.append("\(days)d")
            }
        }

        let title = parts.isEmpty ? "Cursor \(snapshot.planDisplayName)" : parts.joined(separator: " · ")
        let warning = snapshot.highestWatchedPercent >= preferences.warningThresholdPercent
        return .init(title: title, showWarningDot: warning)
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
