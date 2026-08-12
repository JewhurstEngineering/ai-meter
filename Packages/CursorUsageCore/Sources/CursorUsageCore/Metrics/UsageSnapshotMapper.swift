import Foundation

public enum UsageSnapshotMapper {
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        return isoFractional.date(from: string) ?? iso.date(from: string)
    }

    static func map(
        summary: UsageSummaryResponse,
        stripe: AuthStripeResponse?,
        aggregated: AggregatedUsageResponse?,
        fetchedAt: Date = .now
    ) -> UsageSnapshot {
        let membership = summary.membershipType
            ?? stripe?.individualMembershipType
            ?? stripe?.membershipType
            ?? "unknown"
        let tier = PersonalPlanTier(membershipType: membership)
        let plan = summary.individualUsage?.plan
        let onDemand = summary.individualUsage?.onDemand

        let cursorPct = plan?.autoPercentUsed
            ?? plan?.cursorModelsPercentUsed
            ?? plan?.firstPartyPercentUsed
        let otherPct = plan?.apiPercentUsed
            ?? plan?.apiModelsPercentUsed

        let models: [UsageSnapshot.ModelCost] = (aggregated?.aggregations ?? []).compactMap { row in
            guard let name = row.modelIntent, let cents = row.totalCents else { return nil }
            return .init(model: name, totalCents: cents, tier: row.tier)
        }

        return UsageSnapshot(
            fetchedAt: fetchedAt,
            membershipType: membership,
            planDisplayName: tier.displayName,
            subscriptionStatus: stripe?.subscriptionStatus,
            billingCycleStart: parseDate(summary.billingCycleStart),
            billingCycleEnd: parseDate(summary.billingCycleEnd),
            cursorModelsPercentUsed: cursorPct,
            otherModelsPercentUsed: otherPct,
            totalPercentUsed: plan?.totalPercentUsed,
            planUsedCents: plan?.used,
            planLimitCents: plan?.limit,
            planRemainingCents: plan?.remaining,
            includedCents: plan?.breakdown?.included,
            bonusCents: plan?.breakdown?.bonus,
            onDemandEnabled: onDemand?.enabled ?? false,
            onDemandUsedCents: onDemand?.used,
            onDemandLimitCents: onDemand?.limit,
            modelBreakdown: models.sorted { $0.totalCents > $1.totalCents },
            totalModelCostCents: aggregated?.totalCostCents,
            displayMessages: .init(
                cursorModels: summary.autoModelSelectedDisplayMessage,
                otherModels: summary.namedModelSelectedDisplayMessage
            )
        )
    }
}
