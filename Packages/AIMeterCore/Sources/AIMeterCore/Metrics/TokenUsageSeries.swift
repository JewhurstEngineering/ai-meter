import Foundation

public enum TokenUsageRange: String, CaseIterable, Identifiable, Sendable {
    case oneDay
    case sevenDays
    case thirtyDays
    case monthToDate
    case lastMonth

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .oneDay: return "1d"
        case .sevenDays: return "7d"
        case .thirtyDays: return "30d"
        case .monthToDate: return "MTD"
        case .lastMonth: return "Last month"
        }
    }
}

public struct TokenChartSegment: Identifiable, Equatable, Sendable {
    public var day: Date
    public var model: String
    public var tokens: Int

    public var id: String { "\(day.timeIntervalSince1970)-\(model)" }

    public init(day: Date, model: String, tokens: Int) {
        self.day = day
        self.model = model
        self.tokens = tokens
    }
}

public struct TokenUsageSummary: Equatable, Sendable {
    public var range: TokenUsageRange
    public var rangeStart: Date
    public var rangeEnd: Date
    public var totalTokens: Int
    /// Nil when on-demand spend is on and this API cannot split tokens between included and on-demand.
    public var includedTokens: Int?
    public var onDemandTokens: Int?
    /// Largest models first. "Other" is last when smaller models were folded in.
    public var legend: [String]
    public var segments: [TokenChartSegment]
    /// Days in the range were saved before per-model tokens existed.
    public var awaitingTokenDetail: Bool
    /// The saved days do not reach the start of this range yet.
    public var missingEarlierDays: Bool

    public var dayCount: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 0
        return max(1, days + 1)
    }
}

public enum TokenUsageSeries {
    public static let otherLabel = "Other"
    public static let maxLegendModels = 7

    /// Cursor's usage chart counts input, output, cache write, and cache read together.
    public static func totalTokens(input: Int?, output: Int?, cacheWrite: Int?, cacheRead: Int?) -> Int {
        (input ?? 0) + (output ?? 0) + (cacheWrite ?? 0) + (cacheRead ?? 0)
    }

    public static func bounds(
        _ range: TokenUsageRange,
        now: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let today = calendar.startOfDay(for: now)
        switch range {
        case .oneDay:
            return (today, today)
        case .sevenDays:
            return (calendar.date(byAdding: .day, value: -6, to: today) ?? today, today)
        case .thirtyDays:
            return (calendar.date(byAdding: .day, value: -29, to: today) ?? today, today)
        case .monthToDate:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
            return (start, today)
        case .lastMonth:
            let thisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
            let start = calendar.date(byAdding: .month, value: -1, to: thisMonth) ?? today
            let end = calendar.date(byAdding: .day, value: -1, to: thisMonth) ?? today
            return (start, end)
        }
    }

    public static func summary(
        days: [UsageSnapshot.DailySpend],
        range: TokenUsageRange,
        now: Date = Date(),
        calendar: Calendar = .current,
        onDemandEnabled: Bool = false,
        onDemandUsedCents: Int? = nil
    ) -> TokenUsageSummary {
        let window = bounds(range, now: now, calendar: calendar)
        let selected = days.filter { day in
            let start = calendar.startOfDay(for: day.day)
            return start >= window.start && start <= window.end
        }
        let awaiting = !selected.isEmpty && selected.allSatisfy { !$0.includesTokens }
        let earliest = days.map { calendar.startOfDay(for: $0.day) }.min()
        let missingEarlierDays = earliest == nil || earliest! > window.start

        var totals: [String: Int] = [:]
        for day in selected {
            for share in day.models where share.tokens > 0 {
                totals[share.model, default: 0] += share.tokens
            }
        }
        let ranked = totals.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }.map(\.key)
        var legend = Array(ranked.prefix(maxLegendModels))
        let folded = Set(ranked.dropFirst(maxLegendModels))
        if !folded.isEmpty {
            legend.append(otherLabel)
        }

        var segments: [TokenChartSegment] = []
        for day in selected {
            let dayStart = calendar.startOfDay(for: day.day)
            var byModel: [String: Int] = [:]
            var other = 0
            for share in day.models where share.tokens > 0 {
                if folded.contains(share.model) {
                    other += share.tokens
                } else {
                    byModel[share.model, default: 0] += share.tokens
                }
            }
            for model in legend where model != otherLabel {
                let tokens = byModel[model] ?? 0
                guard tokens > 0 else { continue }
                segments.append(TokenChartSegment(day: dayStart, model: model, tokens: tokens))
            }
            if other > 0 {
                segments.append(TokenChartSegment(day: dayStart, model: otherLabel, tokens: other))
            }
        }

        let total = totals.values.reduce(0, +)
        let split = includedSplit(
            total: total,
            onDemandEnabled: onDemandEnabled,
            onDemandUsedCents: onDemandUsedCents
        )
        return TokenUsageSummary(
            range: range,
            rangeStart: window.start,
            rangeEnd: window.end,
            totalTokens: total,
            includedTokens: split.included,
            onDemandTokens: split.onDemand,
            legend: legend,
            segments: segments,
            awaitingTokenDetail: awaiting,
            missingEarlierDays: missingEarlierDays
        )
    }

    /// On-demand tokens are a separate meter on cursor.com. This endpoint only
    /// reports on-demand in cents, so the split is known when that spend is off or zero.
    static func includedSplit(
        total: Int,
        onDemandEnabled: Bool,
        onDemandUsedCents: Int?
    ) -> (included: Int?, onDemand: Int?) {
        let chargingOnDemand = onDemandEnabled && (onDemandUsedCents ?? 0) > 0
        if chargingOnDemand { return (nil, nil) }
        return (total, 0)
    }
}
