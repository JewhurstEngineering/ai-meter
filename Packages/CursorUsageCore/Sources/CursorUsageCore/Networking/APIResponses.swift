import Foundation

// MARK: - Raw API DTOs (loose decoding)

struct UsageSummaryResponse: Decodable, Sendable {
    var billingCycleStart: String?
    var billingCycleEnd: String?
    var membershipType: String?
    var autoModelSelectedDisplayMessage: String?
    var namedModelSelectedDisplayMessage: String?
    var individualUsage: IndividualUsage?

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
