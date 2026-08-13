import Foundation

/// Local daily spend derived from successive snapshots.
/// Cursor’s personal API has no per-day buckets; Team daily endpoints are unused.
public struct DailyUsageSummary: Codable, Sendable, Equatable {
    public var todayCents: Int
    public var yesterdayCents: Int?
    public var cycleAverageCents: Int?
    public var remainingPaceCents: Int?
    public var cycleDaysElapsed: Int?
    /// Oldest → newest, always 7 entries (0 when that day has no sample).
    public var last7DaysCents: [Int]

    public init(
        todayCents: Int,
        yesterdayCents: Int? = nil,
        cycleAverageCents: Int? = nil,
        remainingPaceCents: Int? = nil,
        cycleDaysElapsed: Int? = nil,
        last7DaysCents: [Int] = Array(repeating: 0, count: 7)
    ) {
        self.todayCents = todayCents
        self.yesterdayCents = yesterdayCents
        self.cycleAverageCents = cycleAverageCents
        self.remainingPaceCents = remainingPaceCents
        self.cycleDaysElapsed = cycleDaysElapsed
        self.last7DaysCents = last7DaysCents
    }
}

struct DailySample: Codable, Equatable, Sendable {
    var day: String
    var openingPlanCents: Int
    var closingPlanCents: Int
    var openingOnDemandCents: Int
    var closingOnDemandCents: Int

    var spendCents: Int {
        max(0, closingPlanCents - openingPlanCents)
            + max(0, closingOnDemandCents - openingOnDemandCents)
    }
}

private struct DailyLedgerPayload: Codable {
    var samples: [DailySample]
}

public enum DailyUsageLedger {
    private static let prefix = "dailyUsage."
    private static let retentionDays = 45

    public static func ingest(
        accountID: UUID,
        snapshot: UsageSnapshot,
        now: Date = .now,
        calendar: Calendar = .current,
        defaults: UserDefaults? = nil
    ) -> DailyUsageSummary {
        let store = defaults ?? preferredDefaults()
        let key = prefix + accountID.uuidString
        var samples = load(key: key, defaults: store)
        let formatter = dayFormatter(calendar)
        let todayKey = formatter.string(from: calendar.startOfDay(for: now))
        let plan = snapshot.planUsedCents ?? 0
        let onDemand = snapshot.onDemandUsedCents ?? 0

        if let idx = samples.firstIndex(where: { $0.day == todayKey }) {
            applyCycleResetIfNeeded(&samples[idx], plan: plan, onDemand: onDemand)
            samples[idx].closingPlanCents = plan
            samples[idx].closingOnDemandCents = onDemand
        } else {
            let previous = samples.last { $0.day < todayKey }
            var openingPlan = previous?.closingPlanCents ?? plan
            var openingOnDemand = previous?.closingOnDemandCents ?? onDemand
            if plan < openingPlan { openingPlan = 0 }
            if onDemand < openingOnDemand { openingOnDemand = 0 }
            samples.append(
                DailySample(
                    day: todayKey,
                    openingPlanCents: openingPlan,
                    closingPlanCents: plan,
                    openingOnDemandCents: openingOnDemand,
                    closingOnDemandCents: onDemand
                )
            )
        }

        samples.sort { $0.day < $1.day }
        if let cutoffDate = calendar.date(
            byAdding: .day,
            value: -retentionDays,
            to: calendar.startOfDay(for: now)
        ) {
            let cutoff = formatter.string(from: cutoffDate)
            samples.removeAll { $0.day < cutoff }
        }
        save(samples, key: key, defaults: store)
        return summarize(
            samples: samples,
            snapshot: snapshot,
            now: now,
            calendar: calendar,
            formatter: formatter
        )
    }

    public static func cycleMetrics(
        snapshot: UsageSnapshot,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (averageCents: Int?, paceCents: Int?, daysElapsed: Int?) {
        let elapsed = snapshot.elapsedDays(now: now, calendar: calendar)
        let average: Int?
        if let used = snapshot.planUsedCents, let elapsed {
            average = used / elapsed
        } else {
            average = nil
        }
        let remaining = snapshot.planRemainingCents
            ?? remainingFromLimit(snapshot)
        let daysLeft = snapshot.remainingDays(now: now, calendar: calendar)
        let pace: Int?
        if let remaining, let daysLeft {
            pace = remaining / max(1, daysLeft)
        } else {
            pace = nil
        }
        return (average, pace, elapsed)
    }

    private static func remainingFromLimit(_ snapshot: UsageSnapshot) -> Int? {
        guard let used = snapshot.planUsedCents, let limit = snapshot.planLimitCents else {
            return nil
        }
        return max(0, limit - used)
    }

    private static func applyCycleResetIfNeeded(_ sample: inout DailySample, plan: Int, onDemand: Int) {
        if plan < sample.openingPlanCents {
            sample.openingPlanCents = 0
        }
        if onDemand < sample.openingOnDemandCents {
            sample.openingOnDemandCents = 0
        }
    }

    private static func summarize(
        samples: [DailySample],
        snapshot: UsageSnapshot,
        now: Date,
        calendar: Calendar,
        formatter: DateFormatter
    ) -> DailyUsageSummary {
        let todayKey = formatter.string(from: calendar.startOfDay(for: now))
        let yesterdayKey = formatter.string(
            from: calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)) ?? now
        )
        let today = samples.first { $0.day == todayKey }?.spendCents ?? 0
        let yesterday = samples.first { $0.day == yesterdayKey }?.spendCents
        let pace = cycleMetrics(snapshot: snapshot, now: now, calendar: calendar)
        return DailyUsageSummary(
            todayCents: today,
            yesterdayCents: yesterday,
            cycleAverageCents: pace.averageCents,
            remainingPaceCents: pace.paceCents,
            cycleDaysElapsed: pace.daysElapsed,
            last7DaysCents: last7Days(samples: samples, now: now, calendar: calendar, formatter: formatter)
        )
    }

    private static func last7Days(
        samples: [DailySample],
        now: Date,
        calendar: Calendar,
        formatter: DateFormatter
    ) -> [Int] {
        let byDay = Dictionary(uniqueKeysWithValues: samples.map { ($0.day, $0.spendCents) })
        let start = calendar.startOfDay(for: now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: start) ?? start
            return byDay[formatter.string(from: day)] ?? 0
        }
    }

    private static func load(key: String, defaults: UserDefaults) -> [DailySample] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode(DailyLedgerPayload.self, from: data))?.samples ?? []
    }

    private static func save(_ samples: [DailySample], key: String, defaults: UserDefaults) {
        let payload = DailyLedgerPayload(samples: samples)
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: key)
        }
    }

    private static func preferredDefaults() -> UserDefaults {
        UserDefaults(suiteName: WidgetSnapshotStore.appGroupID)
            ?? UserDefaults(suiteName: WidgetSnapshotStore.legacyAppGroupID)
            ?? .standard
    }

    private static func dayFormatter(_ calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
