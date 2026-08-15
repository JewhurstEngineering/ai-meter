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
        cycleHistory: [UsageSnapshot.BillingCycleSpend] = [],
        dailySpend: [UsageSnapshot.DailySpend] = [],
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
            ?? plan?.otherModelsPercentUsed

        let models: [UsageSnapshot.ModelCost] = (aggregated?.aggregations ?? []).compactMap { row in
            guard let name = row.modelIntent, let cents = row.totalCents else { return nil }
            return .init(
                model: name,
                totalCents: cents,
                tier: row.tier,
                inputTokens: row.inputTokens?.value,
                outputTokens: row.outputTokens?.value,
                cacheWriteTokens: row.cacheWriteTokens?.value,
                cacheReadTokens: row.cacheReadTokens?.value
            )
        }

        return UsageSnapshot(
            fetchedAt: fetchedAt,
            membershipType: membership,
            planDisplayName: tier.displayName,
            subscriptionStatus: stripe?.subscriptionStatus,
            lastPaymentFailed: stripe?.lastPaymentFailed ?? false,
            pendingCancellationDate: parseDate(stripe?.pendingCancellationDate),
            isYearlyPlan: stripe?.isYearlyPlan ?? false,
            customerBalanceCents: stripe?.customerBalance,
            isOnStudentPlan: stripe?.isOnStudentPlan ?? false,
            studentDiscountApplied: stripe?.studentDiscountApplied ?? false,
            verifiedStudent: stripe?.verifiedStudent ?? false,
            trialEligible: stripe?.trialEligible ?? false,
            trialWasCancelled: stripe?.trialWasCancelled ?? false,
            isTeamMember: stripe?.isTeamMember ?? false,
            billingCycleStart: parseDate(summary.billingCycleStart),
            billingCycleEnd: parseDate(summary.billingCycleEnd),
            cycleHistory: cycleHistory,
            dailySpend: dailySpend,
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
            totalInputTokens: aggregated?.totalInputTokens?.value,
            totalOutputTokens: aggregated?.totalOutputTokens?.value,
            totalCacheWriteTokens: aggregated?.totalCacheWriteTokens?.value,
            totalCacheReadTokens: aggregated?.totalCacheReadTokens?.value,
            displayMessages: .init(
                cursorModels: summary.autoModelSelectedDisplayMessage,
                otherModels: summary.namedModelSelectedDisplayMessage
            ),
            provider: .cursor,
            windows: cursorWindows(
                cursorPct: cursorPct,
                otherPct: otherPct,
                totalPct: plan?.totalPercentUsed,
                cycleEnd: parseDate(summary.billingCycleEnd)
            ),
            spend: SpendMeter(
                title: "On-demand",
                usedCents: onDemand?.used,
                limitCents: onDemand?.limit,
                enabled: onDemand?.enabled ?? false,
                unlimited: (onDemand?.enabled ?? false) && (onDemand?.limit == nil || (onDemand?.limit ?? 0) <= 0)
            )
        )
    }

    private static func cursorWindows(
        cursorPct: Double?,
        otherPct: Double?,
        totalPct: Double?,
        cycleEnd: Date?
    ) -> [QuotaWindow] {
        var windows: [QuotaWindow] = []
        if let cursorPct {
            windows.append(.init(
                id: "cursor_models",
                title: "Cursor Models",
                percentUsed: cursorPct,
                resetsAt: cycleEnd,
                kind: .billingCycle,
                role: .cursorModels
            ))
        }
        if let otherPct {
            windows.append(.init(
                id: "other_models",
                title: "Other Models",
                percentUsed: otherPct,
                resetsAt: cycleEnd,
                kind: .billingCycle,
                role: .otherModels
            ))
        }
        if let totalPct {
            windows.append(.init(
                id: "total_included",
                title: "Total included",
                percentUsed: totalPct,
                resetsAt: cycleEnd,
                kind: .billingCycle,
                role: .totalIncluded
            ))
        }
        return windows
    }
}
