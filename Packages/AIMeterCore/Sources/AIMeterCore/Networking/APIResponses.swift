import Foundation

// MARK: - Raw API DTOs (loose decoding)

struct UsageSummaryResponse: Decodable, Sendable {
    var billingCycleStart: String? = nil
    var billingCycleEnd: String? = nil
    var membershipType: String? = nil
    var autoModelSelectedDisplayMessage: String? = nil
    var namedModelSelectedDisplayMessage: String? = nil
    var individualUsage: IndividualUsage? = nil

    struct IndividualUsage: Decodable, Sendable {
        var plan: PlanUsage?
        var onDemand: OnDemandUsage?
    }

    struct PlanUsage: Decodable, Sendable {
        var enabled: Bool?
        var used: Int?
        var limit: Int?
        var remaining: Int?
        var breakdown: Breakdown?
        var autoPercentUsed: Double?
        var apiPercentUsed: Double?
        var totalPercentUsed: Double?
        var cursorModelsPercentUsed: Double?
        var firstPartyPercentUsed: Double?
        var apiModelsPercentUsed: Double?
        var otherModelsPercentUsed: Double?
    }

    struct Breakdown: Decodable, Sendable {
        var included: Int?
        var bonus: Int?
        var total: Int?
    }

    struct OnDemandUsage: Decodable, Sendable {
        var enabled: Bool?
        var used: Int?
        var limit: Int?
        var remaining: Int?
    }
}

public struct AuthMeResponse: Decodable, Sendable {
    public var email: String?
    public var name: String?
    public var sub: String?
    public var id: Int?
}

struct AuthStripeResponse: Decodable, Sendable {
    var membershipType: String?
    var subscriptionStatus: String?
    var individualMembershipType: String?
    var lastPaymentFailed: Bool?
    var pendingCancellationDate: String?
    var isYearlyPlan: Bool?
    var customerBalance: Int?
    var verifiedStudent: Bool?
    var studentDiscountApplied: Bool?
    var trialEligible: Bool?
    var trialLengthDays: Int?
    var isOnStudentPlan: Bool?
    var trialWasCancelled: Bool?
    var isTeamMember: Bool?
    var teamMembershipType: String?
    var isOnBillableAuto: Bool?
    var paymentRecoveryAction: String?
}

struct AggregatedUsageResponse: Decodable, Sendable {
    var aggregations: [Aggregation]?
    var totalCostCents: Double?
    var totalInputTokens: FlexibleInt?
    var totalOutputTokens: FlexibleInt?
    var totalCacheWriteTokens: FlexibleInt?
    var totalCacheReadTokens: FlexibleInt?

    var isEmptySpend: Bool {
        let models = aggregations ?? []
        let total = totalCostCents ?? 0
        return models.isEmpty && total <= 0
    }

    var resolvedTotalCents: Double {
        if let totalCostCents { return totalCostCents }
        return (aggregations ?? []).reduce(0) { $0 + ($1.totalCents ?? 0) }
    }

    struct Aggregation: Decodable, Sendable {
        var modelIntent: String?
        var totalCents: Double?
        var tier: Int?
        var inputTokens: FlexibleInt?
        var outputTokens: FlexibleInt?
        var cacheWriteTokens: FlexibleInt?
        var cacheReadTokens: FlexibleInt?
    }
}

/// Cursor sometimes emits token counts as strings.
struct FlexibleInt: Decodable, Sendable {
    var value: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
            return
        }
        if let int = try? container.decode(Int.self) {
            value = int
            return
        }
        if let double = try? container.decode(Double.self) {
            value = Int(double.rounded())
            return
        }
        if let string = try? container.decode(String.self) {
            value = Int(string)
            return
        }
        value = nil
    }
}

struct HardLimitResponse: Decodable, Sendable {
    var noUsageBasedAllowed: Bool?
    var hardLimit: Int?
    var perUserMonthlyLimitDollars: Int?
}

/// Cursor dashboard `POST /api/dashboard/get-sand-usage-status`.
/// "Sand" is Grok Bot's weekly allowance, separate from the billing-cycle pools.
struct SandUsageStatus: Decodable, Sendable {
    var usagePercent: Double?
    var hasNonZeroIncludedLimit: Bool?
    var includedLimitZero: Bool?
    var usesPooledEnterpriseAllowance: Bool?
    var nextReset: Date?
    var grokPlanLabel: String?

    private enum CodingKeys: String, CodingKey {
        case usagePercent
        case hasNonZeroIncludedLimit
        case includedLimitZero
        case usesPooledEnterpriseAllowance
        case nextResetTimestampUtc
        case nextResetTimestamp
        case grokPlanLabel
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        usagePercent = Self.flexibleDouble(c, .usagePercent)
        hasNonZeroIncludedLimit = Self.flexibleBool(c, .hasNonZeroIncludedLimit)
        includedLimitZero = Self.flexibleBool(c, .includedLimitZero)
        usesPooledEnterpriseAllowance = Self.flexibleBool(c, .usesPooledEnterpriseAllowance)
        grokPlanLabel = try? c.decodeIfPresent(String.self, forKey: .grokPlanLabel)
        nextReset = Self.flexibleDate(c, .nextResetTimestampUtc) ?? Self.flexibleDate(c, .nextResetTimestamp)
    }

    /// A personal meter only exists when the plan includes an allowance and reports a percent used.
    var includedWindow: (percent: Double, resetsAt: Date?)? {
        guard usesPooledEnterpriseAllowance != true,
              includedLimitZero != true,
              hasNonZeroIncludedLimit == true,
              let usagePercent
        else { return nil }
        return (min(100, max(0, usagePercent)), nextReset)
    }

    private static func flexibleDouble(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Double? {
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(value) }
        if let value = try? c.decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }

    private static func flexibleBool(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Bool? {
        if let value = try? c.decodeIfPresent(Bool.self, forKey: key) { return value }
        return nil
    }

    private static func flexibleDate(
        _ c: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> Date? {
        if let text = try? c.decodeIfPresent(String.self, forKey: key) {
            return UsageSnapshotMapper.parseDate(text)
        }
        let millis: Double?
        if let value = try? c.decodeIfPresent(Double.self, forKey: key) {
            millis = value
        } else if let value = try? c.decodeIfPresent(Int.self, forKey: key) {
            millis = Double(value)
        } else {
            millis = nil
        }
        guard let millis, millis > 0 else { return nil }
        if millis > 1_000_000_000_000 {
            return Date(timeIntervalSince1970: millis / 1000)
        }
        return Date(timeIntervalSince1970: millis)
    }
}
