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

    public func exceedsMenuBarWarnings(_ warnings: DisplayPreferences.MenuBarWarningThresholds) -> Bool {
        if let p = cursorModelsPercentUsed, p >= warnings.cursorModelsPercent { return true }
        if let p = otherModelsPercentUsed, p >= warnings.otherModelsPercent { return true }
        if let p = onDemandAndLimitsPercentUsed, p >= warnings.onDemandAndLimitsPercent { return true }
        return false
    }
}
