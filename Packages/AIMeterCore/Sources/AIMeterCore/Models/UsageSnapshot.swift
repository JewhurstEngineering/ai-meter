import Foundation

/// Normalized usage snapshot consumed by menu bar, settings, widgets, and watch.
public struct UsageSnapshot: Codable, Sendable, Equatable {
    public var fetchedAt: Date
    public var membershipType: String
    public var planDisplayName: String
    public var subscriptionStatus: String?
    public var lastPaymentFailed: Bool
    public var pendingCancellationDate: Date?
    public var isYearlyPlan: Bool
    public var customerBalanceCents: Int?
    public var isOnStudentPlan: Bool
    public var studentDiscountApplied: Bool
    public var verifiedStudent: Bool
    public var trialEligible: Bool
    public var trialWasCancelled: Bool
    public var isTeamMember: Bool

    public var billingCycleStart: Date?
    public var billingCycleEnd: Date?
    /// Completed + current cycle model spend, oldest first. Current cycle is last when present.
    public var cycleHistory: [BillingCycleSpend]
    /// Local-calendar $ totals for the current Cursor cycle (quiet days are $0).
    public var dailySpend: [DailySpend]

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
    public var totalInputTokens: Int?
    public var totalOutputTokens: Int?
    public var totalCacheWriteTokens: Int?
    public var totalCacheReadTokens: Int?

    public var displayMessages: DisplayMessages
    public var provider: ProviderKind
    public var windows: [QuotaWindow]
    public var spend: SpendMeter?

    public struct BillingCycleSpend: Codable, Sendable, Equatable, Identifiable {
        public var id: Date { start }
        public var start: Date
        public var end: Date
        public var totalCents: Double
        public var modelCount: Int
        public var isCurrent: Bool

        public init(start: Date, end: Date, totalCents: Double, modelCount: Int, isCurrent: Bool = false) {
            self.start = start
            self.end = end
            self.totalCents = totalCents
            self.modelCount = modelCount
            self.isCurrent = isCurrent
        }

        public var shortLabel: String {
            start.formatted(.dateTime.month(.abbreviated).year(.twoDigits))
        }
    }

    public struct DailySpend: Codable, Sendable, Equatable {
        public var day: Date
        public var cents: Double

        public init(day: Date, cents: Double) {
            self.day = day
            self.cents = cents
        }
    }

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
        public var inputTokens: Int?
        public var outputTokens: Int?
        public var cacheWriteTokens: Int?
        public var cacheReadTokens: Int?

        public init(
            model: String,
            totalCents: Double,
            tier: Int? = nil,
            inputTokens: Int? = nil,
            outputTokens: Int? = nil,
            cacheWriteTokens: Int? = nil,
            cacheReadTokens: Int? = nil
        ) {
            self.model = model
            self.totalCents = totalCents
            self.tier = tier
            self.inputTokens = inputTokens
            self.outputTokens = outputTokens
            self.cacheWriteTokens = cacheWriteTokens
            self.cacheReadTokens = cacheReadTokens
        }
    }

    public init(
        fetchedAt: Date = .now,
        membershipType: String,
        planDisplayName: String,
        subscriptionStatus: String? = nil,
        lastPaymentFailed: Bool = false,
        pendingCancellationDate: Date? = nil,
        isYearlyPlan: Bool = false,
        customerBalanceCents: Int? = nil,
        isOnStudentPlan: Bool = false,
        studentDiscountApplied: Bool = false,
        verifiedStudent: Bool = false,
        trialEligible: Bool = false,
        trialWasCancelled: Bool = false,
        isTeamMember: Bool = false,
        billingCycleStart: Date? = nil,
        billingCycleEnd: Date? = nil,
        cycleHistory: [BillingCycleSpend] = [],
        dailySpend: [DailySpend] = [],
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
        totalInputTokens: Int? = nil,
        totalOutputTokens: Int? = nil,
        totalCacheWriteTokens: Int? = nil,
        totalCacheReadTokens: Int? = nil,
        displayMessages: DisplayMessages = .init(),
        provider: ProviderKind = .cursor,
        windows: [QuotaWindow] = [],
        spend: SpendMeter? = nil
    ) {
        self.fetchedAt = fetchedAt
        self.membershipType = membershipType
        self.planDisplayName = planDisplayName
        self.subscriptionStatus = subscriptionStatus
        self.lastPaymentFailed = lastPaymentFailed
        self.pendingCancellationDate = pendingCancellationDate
        self.isYearlyPlan = isYearlyPlan
        self.customerBalanceCents = customerBalanceCents
        self.isOnStudentPlan = isOnStudentPlan
        self.studentDiscountApplied = studentDiscountApplied
        self.verifiedStudent = verifiedStudent
        self.trialEligible = trialEligible
        self.trialWasCancelled = trialWasCancelled
        self.isTeamMember = isTeamMember
        self.billingCycleStart = billingCycleStart
        self.billingCycleEnd = billingCycleEnd
        self.cycleHistory = cycleHistory
        self.dailySpend = dailySpend
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
        self.totalInputTokens = totalInputTokens
        self.totalOutputTokens = totalOutputTokens
        self.totalCacheWriteTokens = totalCacheWriteTokens
        self.totalCacheReadTokens = totalCacheReadTokens
        self.displayMessages = displayMessages
        self.provider = provider
        self.windows = windows
        self.spend = spend
    }

    /// Windows the UI should render. Synthesizes Cursor pools when `windows` is empty (legacy snapshots).
    public var effectiveWindows: [QuotaWindow] {
        if !windows.isEmpty { return windows }
        var synthesized: [QuotaWindow] = []
        if let p = cursorModelsPercentUsed {
            synthesized.append(.init(
                id: "cursor_models",
                title: "Cursor Models",
                percentUsed: p,
                resetsAt: billingCycleEnd,
                kind: .billingCycle,
                role: .cursorModels
            ))
        }
        if let p = otherModelsPercentUsed {
            synthesized.append(.init(
                id: "other_models",
                title: "Other Models",
                percentUsed: p,
                resetsAt: billingCycleEnd,
                kind: .billingCycle,
                role: .otherModels
            ))
        }
        if let p = totalPercentUsed {
            synthesized.append(.init(
                id: "total_included",
                title: "Total included",
                percentUsed: p,
                resetsAt: billingCycleEnd,
                kind: .billingCycle,
                role: .totalIncluded
            ))
        }
        return synthesized
    }

    public var nextResetAt: Date? {
        effectiveWindows.compactMap(\.resetsAt).min()
    }

    public var isCursor: Bool { provider == .cursor }

    private static func cycleUSD(_ cents: Double) -> String {
        String(format: "$%.0f", (cents / 100).rounded())
    }

    public var previousCycle: BillingCycleSpend? {
        cycleHistory.filter { !$0.isCurrent }.sorted { $0.start < $1.start }.last
    }

    public var currentCycleSpend: BillingCycleSpend? {
        cycleHistory.first(where: \.isCurrent) ?? cycleHistory.sorted { $0.start < $1.start }.last
    }

    public var cycleComparisonCaption: String? {
        guard let previous = previousCycle else { return nil }
        let currentCents = currentCycleSpend?.totalCents ?? totalModelCostCents
        guard let currentCents else { return nil }
        return "Last cycle \(Self.cycleUSD(previous.totalCents)) · this cycle \(Self.cycleUSD(currentCents))"
    }

    public struct Pace: Sendable, Equatable {
        public enum Status: String, Sendable, Equatable {
            case onTrack
            case ahead
            case overCap
        }

        public var elapsedFraction: Double
        public var usedCents: Double
        public var projectedCycleEndCents: Double
        public var status: Status
        public var caption: String
        public var menuBarText: String

        public var systemImage: String {
            switch status {
            case .onTrack: return "flame"
            case .ahead, .overCap: return "flame.fill"
            }
        }
    }

    /// Typical-day pace: already spent + typical remaining days. Cursor only.
    /// 1 calendar day: too soon to project. After that, pad quiet $0 days through
    /// at least a week, drop the highest day, then median (so a spike plus one
    /// work day cannot set the rest of the month).
    public func pace(now: Date = Date(), calendar: Calendar = .current) -> Pace? {
        guard provider == .cursor else { return nil }
        guard let start = billingCycleStart, let end = billingCycleEnd else { return nil }
        let length = end.timeIntervalSince(start)
        guard length > 0 else { return nil }
        let elapsed = now.timeIntervalSince(start)
        guard elapsed > 0 else { return nil }

        let used: Double
        if let planUsedCents {
            used = Double(planUsedCents)
        } else if let current = currentCycleSpend?.totalCents {
            used = current
        } else if let totalModelCostCents {
            used = totalModelCostCents
        } else {
            return nil
        }

        let fraction = min(1, elapsed / length)
        let elapsedDays = elapsedCalendarDays(now: now, calendar: calendar)
        let typical = DailySpendHistory.typicalDailyCents(
            dailySpend.map(\.cents),
            elapsedDays: elapsedDays
        )
        let daysLeft = remainingDaysAfterToday(now: now, calendar: calendar)
        let includedSuffix: String = {
            guard let limit = planLimitCents, limit > 0 else { return "" }
            return " vs \(Self.cycleUSD(Double(limit))) included"
        }()

        if let typical {
            let projected = used + typical * Double(daysLeft)
            let projectedLabel = Self.cycleUSD(projected)
            let typicalLabel = "Typical ~\(Self.cycleUSD(typical))/day · on pace for \(projectedLabel)\(includedSuffix)"
            let status = paceStatus(
                projected: projected,
                used: used,
                elapsedFraction: fraction,
                extrapolating: true
            )
            let caption: String
            switch status {
            case .onTrack:
                caption = typicalLabel
            case .ahead:
                caption = "Ahead of calendar · \(typicalLabel)"
            case .overCap:
                caption = "Over cap · \(typicalLabel)"
            }
            return Pace(
                elapsedFraction: fraction,
                usedCents: used,
                projectedCycleEndCents: projected,
                status: status,
                caption: caption,
                menuBarText: "~\(projectedLabel)"
            )
        }

        let projected = used
        let status = paceStatus(
            projected: projected,
            used: used,
            elapsedFraction: fraction,
            extrapolating: false
        )
        let soFar = "~\(Self.cycleUSD(used)) so far"
        let caption: String
        switch status {
        case .overCap:
            caption = "Over cap · \(soFar)\(includedSuffix)"
        default:
            caption = "\(soFar) · too soon to pace"
        }
        return Pace(
            elapsedFraction: fraction,
            usedCents: used,
            projectedCycleEndCents: projected,
            status: status,
            caption: caption,
            menuBarText: "~\(Self.cycleUSD(used))"
        )
    }

    private func elapsedCalendarDays(now: Date, calendar: Calendar) -> Int {
        guard let start = billingCycleStart else { return 0 }
        let startDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: now)
        guard today >= startDay else { return 0 }
        let days = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0
        return days + 1
    }

    private func remainingDaysAfterToday(now: Date, calendar: Calendar) -> Int {
        guard let end = billingCycleEnd else { return 0 }
        let today = calendar.startOfDay(for: now)
        let endDay = calendar.startOfDay(for: end)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return 0 }
        let days = calendar.dateComponents([.day], from: tomorrow, to: endDay).day ?? 0
        return max(0, days)
    }

    private func paceStatus(
        projected: Double,
        used: Double,
        elapsedFraction: Double,
        extrapolating: Bool
    ) -> Pace.Status {
        if let limit = planLimitCents, limit > 0 {
            let cap = Double(limit)
            if used > cap { return .overCap }
            if extrapolating, projected > cap { return .overCap }
            if extrapolating, elapsedFraction > 0, used / cap > elapsedFraction + 0.08 { return .ahead }
            return .onTrack
        }
        if extrapolating, let previous = previousCycle, previous.totalCents > 0, projected > previous.totalCents * 1.15 {
            return .ahead
        }
        return .onTrack
    }

    /// True when Stripe reported a problem worth showing (failed payment or pending cancel).
    public var hasBillingAlert: Bool {
        lastPaymentFailed || pendingCancellationDate != nil
    }

    public var daysRemainingInCycle: Int? {
        guard let end = billingCycleEnd else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: end).day
        return days.map { max(0, $0) }
    }

    public var highestWatchedPercent: Double {
        let fromPools = [cursorModelsPercentUsed, otherModelsPercentUsed, totalPercentUsed]
            .compactMap { $0 }
        let fromWindows = effectiveWindows.map(\.percentUsed)
        return (fromPools + fromWindows).max() ?? 0
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
        case session
        case weekly

        public var title: String {
            switch self {
            case .cursorModels: return "Cursor Models"
            case .otherModels: return "Other Models"
            case .totalIncluded: return "Total included"
            case .onDemandAndLimits: return "On-demand & limits"
            case .session: return "Session"
            case .weekly: return "Weekly"
            }
        }

        public var shortTitle: String {
            switch self {
            case .cursorModels: return "Cursor"
            case .otherModels: return "Other"
            case .totalIncluded: return "Total"
            case .onDemandAndLimits: return "Spend"
            case .session: return "Session"
            case .weekly: return "Weekly"
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

        public var compactLine: String {
            "\(channel.shortTitle) \(current) @ \(threshold)"
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
        case .session: return "\(Int(warnings.sessionPercent.rounded()))%"
        case .weekly: return "\(Int(warnings.weeklyPercent.rounded()))%"
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
            guard let p = totalPercentUsed ?? windowPercent(role: .totalIncluded) else { return nil }
            return (p >= warnings.totalIncludedPercent, "\(Int(p.rounded()))%")
        case .session:
            guard let p = windowPercent(role: .session) else { return nil }
            return (p >= warnings.sessionPercent, "\(Int(p.rounded()))%")
        case .weekly:
            guard let p = windowPercent(role: .weekly) else { return nil }
            return (p >= warnings.weeklyPercent, "\(Int(p.rounded()))%")
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

    private func windowPercent(role: QuotaWindowRole) -> Double? {
        effectiveWindows.first { $0.role == role }?.percentUsed
    }
}
