import Foundation

/// Normalized usage snapshot consumed by menu bar, settings, widgets, and watch.
public struct UsageSnapshot: Codable, Sendable, Equatable {
    public var fetchedAt: Date
    public var membershipType: String
    public var planDisplayName: String
    public var subscriptionStatus: String?

    public var billingCycleStart: Date?
    public var billingCycleEnd: Date?

    /// Cursor Models (dashboard "auto" / first-party pool).
    public var cursorModelsPercentUsed: Double?
    /// Other Models (dashboard API / named models pool).
    public var otherModelsPercentUsed: Double?
    /// Overall included pool percent when Cursor reports it.
    public var totalPercentUsed: Double?

    /// Plan spend in USD cents (credit-based plans).
    public var planUsedCents: Int?
    public var planLimitCents: Int?
    public var planRemainingCents: Int?
    public var includedCents: Int?
    public var bonusCents: Int?

    public var onDemandEnabled: Bool
    public var onDemandUsedCents: Int?
    public var onDemandLimitCents: Int?

    public var modelBreakdown: [ModelCost]
    public var totalModelCostCents: Double?

    public var displayMessages: DisplayMessages

    public struct DisplayMessages: Codable, Sendable, Equatable {
        public var cursorModels: String?
        public var otherModels: String?

        public init(cursorModels: String? = nil, otherModels: String? = nil) {
            self.cursorModels = cursorModels
            self.otherModels = otherModels
        }
    }

    public struct ModelCost: Codable, Sendable, Equatable, Identifiable {
        public var id: String { model }
        public var model: String
        public var totalCents: Double
        public var tier: Int?

        public init(model: String, totalCents: Double, tier: Int? = nil) {
            self.model = model
            self.totalCents = totalCents
            self.tier = tier
        }
    }

    public init(
        fetchedAt: Date = .now,
        membershipType: String,
        planDisplayName: String,
        subscriptionStatus: String? = nil,
        billingCycleStart: Date? = nil,
        billingCycleEnd: Date? = nil,
        cursorModelsPercentUsed: Double? = nil,
        otherModelsPercentUsed: Double? = nil,
        totalPercentUsed: Double? = nil,
        planUsedCents: Int? = nil,
        planLimitCents: Int? = nil,
        planRemainingCents: Int? = nil,
        includedCents: Int? = nil,
        bonusCents: Int? = nil,
        onDemandEnabled: Bool = false,
        onDemandUsedCents: Int? = nil,
        onDemandLimitCents: Int? = nil,
        modelBreakdown: [ModelCost] = [],
        totalModelCostCents: Double? = nil,
        displayMessages: DisplayMessages = .init()
    ) {
        self.fetchedAt = fetchedAt
        self.membershipType = membershipType
        self.planDisplayName = planDisplayName
        self.subscriptionStatus = subscriptionStatus
        self.billingCycleStart = billingCycleStart
        self.billingCycleEnd = billingCycleEnd
        self.cursorModelsPercentUsed = cursorModelsPercentUsed
        self.otherModelsPercentUsed = otherModelsPercentUsed
        self.totalPercentUsed = totalPercentUsed
        self.planUsedCents = planUsedCents
        self.planLimitCents = planLimitCents
        self.planRemainingCents = planRemainingCents
        self.includedCents = includedCents
        self.bonusCents = bonusCents
        self.onDemandEnabled = onDemandEnabled
        self.onDemandUsedCents = onDemandUsedCents
        self.onDemandLimitCents = onDemandLimitCents
        self.modelBreakdown = modelBreakdown
        self.totalModelCostCents = totalModelCostCents
        self.displayMessages = displayMessages
    }

    public var daysRemainingInCycle: Int? {
        guard let end = billingCycleEnd else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: end).day
        return days.map { max(0, $0) }
    }

    public var highestWatchedPercent: Double {
        [cursorModelsPercentUsed, otherModelsPercentUsed, totalPercentUsed]
            .compactMap { $0 }
            .max() ?? 0
    }

    /// Max of plan-included spend % and on-demand spend % (when a limit exists).
    public var onDemandAndLimitsPercentUsed: Double? {
        var values: [Double] = []
        if let used = planUsedCents, let limit = planLimitCents, limit > 0 {
            values.append(min(100, Double(used) / Double(limit) * 100))
        }
        if let used = onDemandUsedCents, let limit = onDemandLimitCents, limit > 0 {
            values.append(min(100, Double(used) / Double(limit) * 100))
        }
        return values.max()
    }

    /// On-demand enabled with no positive spend cap (Cursor “unlimited”).
    public var isOnDemandUnlimited: Bool {
        onDemandEnabled && (onDemandLimitCents == nil || (onDemandLimitCents ?? 0) <= 0)
    }

    public func exceedsMenuBarWarnings(_ warnings: DisplayPreferences.MenuBarWarningThresholds) -> Bool {
        !menuBarWarningHits(warnings).isEmpty
    }

    public enum WarningChannel: String, Sendable, CaseIterable {
        case cursorModels
        case otherModels
        case onDemandAndLimits
        case totalIncluded

        public var title: String {
            switch self {
            case .cursorModels: return "Cursor Models"
            case .otherModels: return "Other Models"
            case .totalIncluded: return "Total included"
            case .onDemandAndLimits: return "On-demand & limits"
            }
        }
    }

    public struct MenuBarWarningHit: Sendable, Equatable, Identifiable {
        public var id: String { channel.rawValue }
        public var channel: WarningChannel
        public var current: String
        public var threshold: String

        public var sentence: String {
            "\(channel.title) is at \(current) (alert set to \(threshold))"
        }

        public init(channel: WarningChannel, current: String, threshold: String) {
            self.channel = channel
            self.current = current
            self.threshold = threshold
        }
    }

    public func menuBarWarningHits(
        _ warnings: DisplayPreferences.MenuBarWarningThresholds
    ) -> [MenuBarWarningHit] {
        WarningChannel.allCases.compactMap { channel in
            guard let status = warningChannelStatus(channel, warnings: warnings), status.triggered else {
                return nil
            }
            return MenuBarWarningHit(
                channel: channel,
                current: status.detail,
                threshold: warningThresholdLabel(channel, warnings: warnings)
            )
        }
    }

    private func warningThresholdLabel(
        _ channel: WarningChannel,
        warnings: DisplayPreferences.MenuBarWarningThresholds
    ) -> String {
        switch channel {
        case .cursorModels: return "\(Int(warnings.cursorModelsPercent.rounded()))%"
        case .otherModels: return "\(Int(warnings.otherModelsPercent.rounded()))%"
        case .totalIncluded: return "\(Int(warnings.totalIncludedPercent.rounded()))%"
        case .onDemandAndLimits:
            if isOnDemandUnlimited,
               let used = onDemandUsedCents,
               used >= warnings.onDemandUnlimitedAlertCents
            {
                return MenuBarFormatter.usd(warnings.onDemandUnlimitedAlertCents)
            }
            return "\(Int(warnings.onDemandAndLimitsPercent.rounded()))%"
        }
    }

    public func warningChannelStatus(
        _ channel: WarningChannel,
        warnings: DisplayPreferences.MenuBarWarningThresholds
    ) -> (triggered: Bool, detail: String)? {
        switch channel {
        case .cursorModels:
            guard let p = cursorModelsPercentUsed else { return nil }
            return (p >= warnings.cursorModelsPercent, "\(Int(p.rounded()))%")
        case .otherModels:
            guard let p = otherModelsPercentUsed else { return nil }
            return (p >= warnings.otherModelsPercent, "\(Int(p.rounded()))%")
        case .totalIncluded:
            guard let p = totalPercentUsed else { return nil }
            return (p >= warnings.totalIncludedPercent, "\(Int(p.rounded()))%")
        case .onDemandAndLimits:
            if isOnDemandUnlimited {
                if let used = onDemandUsedCents, used >= warnings.onDemandUnlimitedAlertCents {
                    return (true, "\(MenuBarFormatter.usd(used)) on-demand")
                }
                if let used = planUsedCents, let limit = planLimitCents, limit > 0 {
                    let p = min(100, Double(used) / Double(limit) * 100)
                    if p >= warnings.onDemandAndLimitsPercent {
                        return (true, "\(Int(p.rounded()))% plan")
                    }
                }
                if let used = onDemandUsedCents {
                    return (false, "\(MenuBarFormatter.usd(used)) on-demand")
                }
                return nil
            }
            guard let p = onDemandAndLimitsPercentUsed else { return nil }
            return (p >= warnings.onDemandAndLimitsPercent, "\(Int(p.rounded()))%")
        }
    }
}
