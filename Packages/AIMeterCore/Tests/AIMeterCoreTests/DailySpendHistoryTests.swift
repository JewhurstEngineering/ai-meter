import XCTest
@testable import AIMeterCore

final class DailySpendHistoryTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testTypicalDailyRules() {
        XCTAssertNil(DailySpendHistory.typicalDailyCents([], elapsedDays: 0, minimumSampleDays: 0))
        XCTAssertNil(DailySpendHistory.typicalDailyCents([100], elapsedDays: 1, minimumSampleDays: 0))
        XCTAssertEqual(
            DailySpendHistory.typicalDailyCents([100, 5], elapsedDays: 2, minimumSampleDays: 0),
            5
        )
        XCTAssertEqual(
            DailySpendHistory.typicalDailyCents([10, 20, 400], elapsedDays: 3, minimumSampleDays: 0),
            15
        )
        XCTAssertEqual(
            DailySpendHistory.typicalDailyCents([10, 20, 30, 400], elapsedDays: 4, minimumSampleDays: 0),
            20
        )
        XCTAssertEqual(
            DailySpendHistory.typicalDailyCents([0, 0, 40_000], elapsedDays: 3, minimumSampleDays: 0),
            0
        )
    }

    func testTypicalDailyPadsYoungCycleSoWorkDaysDoNotSetTheMonth() {
        XCTAssertEqual(
            DailySpendHistory.typicalDailyCents([32_200, 8_900], elapsedDays: 2),
            0
        )
        XCTAssertEqual(
            DailySpendHistory.typicalDailyCents([8_900, 8_900, 8_900], elapsedDays: 3),
            0
        )
    }

    func testTypicalDailyKeepsSteadyWeekdayRateAfterAWeek() {
        let week = Array(repeating: 2_000.0, count: 7)
        XCTAssertEqual(DailySpendHistory.typicalDailyCents(week, elapsedDays: 7), 2_000)
    }

    func testDayWindowsSplitsFromCycleStartThroughToday() {
        let start = Date(timeIntervalSince1970: 1_704_110_400)
        let end = Date(timeIntervalSince1970: 1_706_702_400)
        let now = Date(timeIntervalSince1970: 1_704_294_000)
        let windows = DailySpendHistory.dayWindows(
            cycleStart: start,
            cycleEnd: end,
            now: now,
            calendar: utc
        )
        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows[0].start, start)
        XCTAssertTrue(windows[0].isComplete)
        XCTAssertTrue(windows[1].isComplete)
        XCTAssertFalse(windows[2].isComplete)
        XCTAssertEqual(windows[2].end.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
    }

    func testFillUsesCacheForCompletedDaysAndRefetchesToday() async {
        let start = Date(timeIntervalSince1970: 1_704_110_400)
        let end = Date(timeIntervalSince1970: 1_706_702_400)
        let now = Date(timeIntervalSince1970: 1_704_294_000)
        let windows = DailySpendHistory.dayWindows(
            cycleStart: start,
            cycleEnd: end,
            now: now,
            calendar: utc
        )
        let cachedDay = windows[0].day
        let cache = CachedDailySpend(
            cycleStart: start,
            days: [.init(day: cachedDay, cents: 1_234)]
        )
        let log = FetchCallLog()
        let days = await DailySpendHistory.fill(
            cycleStart: start,
            cycleEnd: end,
            now: now,
            cached: cache,
            calendar: utc,
            concurrency: 3
        ) { windowStart, windowEnd in
            await log.record(windowStart, windowEnd)
            return 50
        }
        let calls = await log.calls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(days.count, 3)
        XCTAssertEqual(days.first { abs($0.day.timeIntervalSince(cachedDay)) < 2 }?.cents, 1_234)
        XCTAssertFalse(days.contains { $0.cents == 1_234 && abs($0.day.timeIntervalSince(windows[2].day)) < 2 })
    }

    func testFillRecordsZeroForEmptySpendAndOmitsFailures() async {
        let start = Date(timeIntervalSince1970: 1_704_067_200)
        let end = Date(timeIntervalSince1970: 1_706_702_400)
        let now = Date(timeIntervalSince1970: 1_704_283_200)
        let windows = DailySpendHistory.dayWindows(
            cycleStart: start,
            cycleEnd: end,
            now: now,
            calendar: utc
        )
        XCTAssertEqual(windows.count, 3)
        let log = FetchOutcomeLog()
        let days = await DailySpendHistory.fill(
            cycleStart: start,
            cycleEnd: end,
            now: now,
            cached: nil,
            calendar: utc,
            concurrency: 1
        ) { _, _ in
            await log.next()
        }
        XCTAssertEqual(days.count, 2)
        XCTAssertEqual(days[0].cents, 0)
        XCTAssertEqual(days[1].cents, 75)
    }

    func testStoreRoundTrip() {
        let suite = UserDefaults(suiteName: "DailySpendHistoryTests.\(UUID().uuidString)")!
        let store = DailySpendHistoryStore(defaults: suite)
        let start = Date(timeIntervalSince1970: 1_704_067_200)
        let cached = CachedDailySpend(
            cycleStart: start,
            days: [.init(day: start, cents: 99)]
        )
        store.save(userID: 42, cached)
        let loaded = store.load(userID: 42)
        XCTAssertEqual(loaded?.cycleStart, start)
        XCTAssertEqual(loaded?.days.first?.cents, 99)
        XCTAssertNil(store.load(userID: 99))
    }
}

private actor FetchCallLog {
    var calls: [(Date, Date)] = []

    func record(_ start: Date, _ end: Date) {
        calls.append((start, end))
    }
}

private actor FetchOutcomeLog {
    private var index = 0
    private let values: [Double?] = [0, nil, 75]

    func next() -> Double? {
        defer { index += 1 }
        guard index < values.count else { return nil }
        return values[index]
    }
}
