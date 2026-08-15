import Foundation

public struct CachedDailySpend: Codable, Sendable, Equatable {
    public var cycleStart: Date
    public var days: [UsageSnapshot.DailySpend]

    public init(cycleStart: Date, days: [UsageSnapshot.DailySpend] = []) {
        self.cycleStart = cycleStart
        self.days = days
    }
}

public enum DailySpendHistory {
    public static let maxConcurrency = 3

    public struct DayWindow: Sendable, Equatable {
        public var start: Date
        public var end: Date
        public var day: Date
        public var isComplete: Bool
    }

    /// Local-calendar slices of the current cycle through `now`. The first window
    /// starts at `cycleStart` (mid-day ok). Completed days end at the next midnight.
    public static func dayWindows(
        cycleStart: Date,
        cycleEnd: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> [DayWindow] {
        guard cycleEnd > cycleStart, now > cycleStart else { return [] }
        var windows: [DayWindow] = []
        var cursor = cycleStart
        let todayStart = calendar.startOfDay(for: now)
        while cursor < now, cursor < cycleEnd, windows.count < 40 {
            let day = calendar.startOfDay(for: cursor)
            guard let nextMidnight = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            let windowEnd = min(nextMidnight, cycleEnd)
            let isComplete = day < todayStart
            let fetchEnd = isComplete ? windowEnd : min(max(now, cursor.addingTimeInterval(1)), cycleEnd)
            windows.append(DayWindow(start: cursor, end: fetchEnd, day: day, isComplete: isComplete))
            cursor = windowEnd
        }
        return windows
    }

    /// Robust typical $/day for remaining-day projection.
    /// Pads with $0 up to `elapsedDays` (missing quiet/failed days) and at least
    /// `minimumSampleDays` (young cycle: two work days must not set the month).
    /// Then drops the single highest day and takes the median of the rest.
    /// Nil when there is only one elapsed day (too soon to pace).
    public static func typicalDailyCents(
        _ cents: [Double],
        elapsedDays: Int,
        minimumSampleDays: Int = 7
    ) -> Double? {
        guard elapsedDays >= 2 else { return nil }
        var samples = cents
        let padTo = max(elapsedDays, minimumSampleDays)
        if samples.count < padTo {
            samples.append(contentsOf: repeatElement(0, count: padTo - samples.count))
        }
        guard samples.count >= 2 else { return nil }
        if let peak = samples.max(), let index = samples.firstIndex(of: peak) {
            samples.remove(at: index)
        }
        return median(samples)
    }

    public static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        guard count > 0 else { return 0 }
        if count % 2 == 1 { return sorted[count / 2] }
        return (sorted[count / 2 - 1] + sorted[count / 2]) / 2
    }

    public static func cachedDay(
        _ cached: [UsageSnapshot.DailySpend],
        day: Date
    ) -> UsageSnapshot.DailySpend? {
        cached.first { abs($0.day.timeIntervalSince(day)) < 2 }
    }

    /// Fills missing completed days from cache; always refetches today.
    /// Failed fetches leave that day out (not $0). Empty spend is $0.
    public static func fill(
        cycleStart: Date,
        cycleEnd: Date,
        now: Date = Date(),
        cached: CachedDailySpend?,
        calendar: Calendar = .current,
        concurrency: Int = maxConcurrency,
        fetch: @escaping @Sendable (Date, Date) async -> Double?
    ) async -> [UsageSnapshot.DailySpend] {
        let windows = dayWindows(cycleStart: cycleStart, cycleEnd: cycleEnd, now: now, calendar: calendar)
        let cache: [UsageSnapshot.DailySpend]
        if let cached, abs(cached.cycleStart.timeIntervalSince(cycleStart)) < 2 {
            cache = cached.days
        } else {
            cache = []
        }

        var byDay: [TimeInterval: UsageSnapshot.DailySpend] = [:]
        var toFetch: [DayWindow] = []
        for window in windows {
            if window.isComplete, let hit = cachedDay(cache, day: window.day) {
                byDay[window.day.timeIntervalSince1970] = hit
            } else {
                toFetch.append(window)
            }
        }

        let chunkSize = max(1, concurrency)
        var index = 0
        while index < toFetch.count {
            let chunk = Array(toFetch[index..<min(index + chunkSize, toFetch.count)])
            index += chunk.count
            await withTaskGroup(of: (DayWindow, Double?).self) { group in
                for window in chunk {
                    group.addTask {
                        (window, await fetch(window.start, window.end))
                    }
                }
                for await (window, cents) in group {
                    guard let cents else { continue }
                    byDay[window.day.timeIntervalSince1970] = UsageSnapshot.DailySpend(
                        day: window.day,
                        cents: cents
                    )
                }
            }
        }

        return byDay.values.sorted { $0.day < $1.day }
    }
}

public struct DailySpendHistoryStore {
    private let defaults: UserDefaults
    private let keyPrefix = "cursor.dailySpend."

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load(userID: Int) -> CachedDailySpend? {
        let key = keyPrefix + String(userID)
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CachedDailySpend.self, from: data)
    }

    public func save(userID: Int, _ cache: CachedDailySpend) {
        let key = keyPrefix + String(userID)
        guard let data = try? JSONEncoder().encode(cache) else { return }
        defaults.set(data, forKey: key)
    }
}
