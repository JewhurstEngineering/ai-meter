import XCTest
@testable import AIMeterCore

final class TokenUsageSeriesTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date {
        utc.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 15))!
    }

    func testTotalIncludesCacheTokens() {
        XCTAssertEqual(
            TokenUsageSeries.totalTokens(input: 100, output: 20, cacheWrite: 30, cacheRead: 400),
            550
        )
    }

    func testRangesMatchTheUsagePageChips() {
        let seven = TokenUsageSeries.bounds(.sevenDays, now: now, calendar: utc)
        XCTAssertEqual(seven.start, day(2026, 9, 30))
        XCTAssertEqual(seven.end, day(2026, 10, 6))

        let month = TokenUsageSeries.bounds(.thirtyDays, now: now, calendar: utc)
        XCTAssertEqual(month.start, day(2026, 9, 7))
        XCTAssertEqual(month.end, day(2026, 10, 6))

        let mtd = TokenUsageSeries.bounds(.monthToDate, now: now, calendar: utc)
        XCTAssertEqual(mtd.start, day(2026, 10, 1))

        let last = TokenUsageSeries.bounds(.lastMonth, now: now, calendar: utc)
        XCTAssertEqual(last.start, day(2026, 9, 1))
        XCTAssertEqual(last.end, day(2026, 9, 30))
    }

    func testSevenDayTotalAndOtherBucket() {
        var days: [UsageSnapshot.DailySpend] = []
        days.append(spend(day(2026, 9, 1), model: "old", tokens: 1_000))
        for offset in 0..<6 {
            let date = utc.date(byAdding: .day, value: offset, to: day(2026, 9, 30))!
            days.append(spend(date, model: "grok-4.7-high", tokens: 100))
        }
        days.append(.init(
            day: day(2026, 10, 6),
            cents: 0,
            models: (1...8).map { .init(model: "m\($0)", tokens: $0) }
        ))

        let summary = TokenUsageSeries.summary(
            days: days,
            range: .sevenDays,
            now: now,
            calendar: utc,
            onDemandEnabled: false,
            onDemandUsedCents: 0
        )
        XCTAssertEqual(summary.totalTokens, 600 + (1...8).reduce(0, +))
        XCTAssertEqual(summary.includedTokens, summary.totalTokens)
        XCTAssertEqual(summary.onDemandTokens, 0)
        XCTAssertEqual(summary.legend.last, TokenUsageSeries.otherLabel)
        XCTAssertEqual(summary.legend.count, 8)
        XCTAssertFalse(summary.legend.dropLast().contains("m1"))
        let other = summary.segments.first { $0.day == day(2026, 10, 6) && $0.model == "Other" }
        XCTAssertEqual(other?.tokens, 3)
    }

    func testOnDemandSpendHidesTheTokenSplit() {
        let days = [spend(day(2026, 10, 6), model: "grok-4.7-high", tokens: 50)]
        let summary = TokenUsageSeries.summary(
            days: days,
            range: .oneDay,
            now: now,
            calendar: utc,
            onDemandEnabled: true,
            onDemandUsedCents: 120
        )
        XCTAssertEqual(summary.totalTokens, 50)
        XCTAssertNil(summary.includedTokens)
        XCTAssertNil(summary.onDemandTokens)
    }

    func testDisabledOnDemandStillCountsAsIncluded() {
        let days = [spend(day(2026, 10, 6), model: "grok-4.7-high", tokens: 50)]
        let summary = TokenUsageSeries.summary(
            days: days,
            range: .oneDay,
            now: now,
            calendar: utc,
            onDemandEnabled: false,
            onDemandUsedCents: 25_704
        )
        XCTAssertEqual(summary.includedTokens, 50)
        XCTAssertEqual(summary.onDemandTokens, 0)
    }

    func testFixtureAggregationSumsEveryTokenKind() throws {
        let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent("aggregated_usage_ultra.json")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(AggregatedUsageResponse.self, from: data)
        let shares = decoded.dailyModelShares
        XCTAssertEqual(shares.reduce(0) { $0 + $1.tokens }, 410_497_672)
        XCTAssertEqual(shares.first?.model, "claude-fable-5-thinking-high")
    }

    private func day(_ year: Int, _ month: Int, _ d: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: d))!
    }

    private func spend(_ day: Date, model: String, tokens: Int) -> UsageSnapshot.DailySpend {
        .init(day: day, cents: 0, models: [.init(model: model, tokens: tokens)])
    }
}
