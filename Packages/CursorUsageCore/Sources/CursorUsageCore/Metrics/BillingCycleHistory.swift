import Foundation

public struct CachedCycleHistory: Codable, Sendable, Equatable {
    public var cycles: [UsageSnapshot.BillingCycleSpend]
    public var reachedEnd: Bool

    public init(cycles: [UsageSnapshot.BillingCycleSpend] = [], reachedEnd: Bool = false) {
        self.cycles = cycles
        self.reachedEnd = reachedEnd
    }
}

public enum BillingCycleHistory {
    public static let maxPreviousWindows = 12
    public static let emptyStreakToStop = 2

    public enum FetchOutcome: Sendable, Equatable {
        case spend(UsageSnapshot.BillingCycleSpend)
        case empty
        case failed
    }

    public struct WalkResult: Sendable, Equatable {
        public var cycles: [UsageSnapshot.BillingCycleSpend]
        public var reachedEnd: Bool
        public var fetchedWindows: Int

        public init(cycles: [UsageSnapshot.BillingCycleSpend], reachedEnd: Bool, fetchedWindows: Int) {
            self.cycles = cycles
            self.reachedEnd = reachedEnd
            self.fetchedWindows = fetchedWindows
        }
    }

    /// Epoch-ms string for `startDate` / `endDate`. Real cycle instants, never the `"0"` all-time sentinel.
    public static func aggregatedDateMillis(_ date: Date) -> String {
        String(Int64((date.timeIntervalSince1970 * 1000).rounded()))
    }

    public static func previous(start: Date, end: Date) -> (start: Date, end: Date)? {
        let length = end.timeIntervalSince(start)
        guard length > 0 else { return nil }
        return (start.addingTimeInterval(-length), start)
    }

    public static func previousWindows(start: Date, end: Date, count: Int) -> [(start: Date, end: Date)] {
        var windows: [(start: Date, end: Date)] = []
        var cursorStart = start
        var cursorEnd = end
        for _ in 0..<count {
            guard let next = previous(start: cursorStart, end: cursorEnd) else { break }
            windows.append(next)
            cursorEnd = next.end
            cursorStart = next.start
        }
        return windows
    }

    static func spend(
        from response: AggregatedUsageResponse,
        start: Date,
        end: Date,
        isCurrent: Bool = false
    ) -> UsageSnapshot.BillingCycleSpend? {
        guard !response.isEmptySpend else { return nil }
        return .init(
            start: start,
            end: end,
            totalCents: response.resolvedTotalCents,
            modelCount: response.aggregations?.count ?? 0,
            isCurrent: isCurrent
        )
    }

    public static func cachedMatch(
        _ cached: [UsageSnapshot.BillingCycleSpend],
        start: Date
    ) -> UsageSnapshot.BillingCycleSpend? {
        cached.first { abs($0.start.timeIntervalSince(start)) < 2 }
    }

    /// Walks older same-length windows. Uses cache hits without fetching. Stops after two
    /// consecutive empty live responses, or when `reachedEnd` is already true and the
    /// window is older than the oldest cached cycle.
    public static func walkPrevious(
        currentStart: Date,
        currentEnd: Date,
        cached: CachedCycleHistory,
        maxWindows: Int = maxPreviousWindows,
        fetch: (Date, Date) async -> FetchOutcome
    ) async -> WalkResult {
        var collected = cached.cycles.filter { !$0.isCurrent }
        var reachedEnd = cached.reachedEnd
        var emptyStreak = 0
        var fetched = 0
        let oldestCached = collected.map(\.start).min()

        var cursorStart = currentStart
        var cursorEnd = currentEnd

        windowLoop: for _ in 0..<maxWindows {
            guard let window = previous(start: cursorStart, end: cursorEnd) else { break }

            if reachedEnd, let oldestCached, window.end <= oldestCached.addingTimeInterval(2) {
                break
            }

            if cachedMatch(collected, start: window.start) != nil {
                emptyStreak = 0
                cursorStart = window.start
                cursorEnd = window.end
                continue
            }

            fetched += 1
            switch await fetch(window.start, window.end) {
            case .spend(let cycle):
                emptyStreak = 0
                if cachedMatch(collected, start: cycle.start) == nil {
                    collected.append(cycle)
                }
            case .empty:
                emptyStreak += 1
                if emptyStreak >= emptyStreakToStop {
                    reachedEnd = true
                    break windowLoop
                }
            case .failed:
                return WalkResult(
                    cycles: collected.sorted { $0.start < $1.start },
                    reachedEnd: reachedEnd,
                    fetchedWindows: fetched
                )
            }

            cursorStart = window.start
            cursorEnd = window.end
        }

        return WalkResult(
            cycles: collected.sorted { $0.start < $1.start },
            reachedEnd: reachedEnd,
            fetchedWindows: fetched
        )
    }

    public static func mergedHistory(
        current: UsageSnapshot.BillingCycleSpend?,
        previous: [UsageSnapshot.BillingCycleSpend]
    ) -> [UsageSnapshot.BillingCycleSpend] {
        var rows = previous.map {
            UsageSnapshot.BillingCycleSpend(
                start: $0.start,
                end: $0.end,
                totalCents: $0.totalCents,
                modelCount: $0.modelCount,
                isCurrent: false
            )
        }
        if let current {
            rows.removeAll { abs($0.start.timeIntervalSince(current.start)) < 2 }
            rows.append(current)
        }
        return rows.sorted { $0.start < $1.start }
    }
}

public struct BillingCycleHistoryStore {
    private let defaults: UserDefaults
    private let keyPrefix = "cursor.billingCycleHistory."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load(userID: Int) -> CachedCycleHistory {
        let key = keyPrefix + String(userID)
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(CachedCycleHistory.self, from: data)
        else {
            return CachedCycleHistory()
        }
        return decoded
    }

    public func save(userID: Int, _ history: CachedCycleHistory) {
        let key = keyPrefix + String(userID)
        let completed = CachedCycleHistory(
            cycles: history.cycles.filter { !$0.isCurrent },
            reachedEnd: history.reachedEnd
        )
        guard let data = try? JSONEncoder().encode(completed) else { return }
        defaults.set(data, forKey: key)
    }
}
