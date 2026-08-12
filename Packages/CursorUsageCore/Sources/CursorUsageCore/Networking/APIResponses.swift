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
}

struct AggregatedUsageResponse: Decodable, Sendable {
    var aggregations: [Aggregation]?
    var totalCostCents: Double?

    struct Aggregation: Decodable, Sendable {
        var modelIntent: String?
        var totalCents: Double?
        var tier: Int?
    }
}

struct HardLimitResponse: Decodable, Sendable {
    var noUsageBasedAllowed: Bool?
    var hardLimit: Int?
    var perUserMonthlyLimitDollars: Int?
}
