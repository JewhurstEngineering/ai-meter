import XCTest
@testable import CursorUsageCore

final class DailyUsageLedgerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var calendar: Calendar!
    private let accountID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    override func setUp() {
        super.setUp()
        suiteName = "daily.ledger.test.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testFirstIngestTodayIsZeroUntilSpendMoves() {
        let now = date(2026, 8, 13, 15)
        let summary = DailyUsageLedger.ingest(
            accountID: accountID,
            snapshot: snapshot(plan: 24_000, start: date(2026, 8, 1), end: date(2026, 8, 31)),
            now: now,
            calendar: calendar,
            defaults: defaults
        )
        XCTAssertEqual(summary.todayCents, 0)
        XCTAssertEqual(summary.last7DaysCents.count, 7)
        XCTAssertEqual(summary.cycleDaysElapsed, 13)
        XCTAssertEqual(summary.cycleAverageCents, 24_000 / 13)
    }

    func testSameDayIncreaseIsTodaySpend() {
        let now = date(2026, 8, 13, 10)
        _ = DailyUsageLedger.ingest(
            accountID: accountID,
            snapshot: snapshot(plan: 24_000),
            now: now,
            calendar: calendar,
            defaults: defaults
        )
        let later = DailyUsageLedger.ingest(
            accountID: accountID,
            snapshot: snapshot(plan: 24_500, onDemand: 200),
            now: date(2026, 8, 13, 18),
            calendar: calendar,
            defaults: defaults
        )
        XCTAssertEqual(later.todayCents, 700)
    }

    func testNextDayUsesYesterdayCloseAsOpening() {
        _ = DailyUsageLedger.ingest(
            accountID: accountID,
            snapshot: snapshot(plan: 10_000),
            now: date(2026, 8, 12, 22),
            calendar: calendar,
            defaults: defaults
        )
        let today = DailyUsageLedger.ingest(
            accountID: accountID,
            snapshot: snapshot(plan: 10_800),
            now: date(2026, 8, 13, 9),
            calendar: calendar,
            defaults: defaults
        )
        XCTAssertEqual(today.todayCents, 800)
        XCTAssertEqual(today.yesterdayCents, 0)
        XCTAssertEqual(today.last7DaysCents.last, 800)
    }

    func testCycleResetTreatsDropAsNewOpening() {
        _ = DailyUsageLedger.ingest(
            accountID: accountID,
            snapshot: snapshot(plan: 39_000),
            now: date(2026, 8, 12, 22),
            calendar: calendar,
            defaults: defaults
        )
        let reset = DailyUsageLedger.ingest(
            accountID: accountID,
            snapshot: snapshot(plan: 150, start: date(2026, 8, 13), end: date(2026, 9, 12)),
            now: date(2026, 8, 13, 8),
            calendar: calendar,
            defaults: defaults
        )
        XCTAssertEqual(reset.todayCents, 150)
        XCTAssertEqual(reset.cycleDaysElapsed, 1)
        XCTAssertEqual(reset.cycleAverageCents, 150)
    }

    func testPaceIsRemainingDividedByDaysLeft() {
        let summary = DailyUsageLedger.ingest(
            accountID: accountID,
            snapshot: snapshot(
                plan: 20_000,
                start: date(2026, 8, 1),
                end: date(2026, 8, 21),
                remaining: 20_000
            ),
            now: date(2026, 8, 11, 12),
            calendar: calendar,
            defaults: defaults
        )
        XCTAssertEqual(summary.remainingPaceCents, 20_000 / 10)
    }

    func testLegacyWidgetSnapshotJSONStillDecodes() throws {
        let json = """
        {"generatedAt":0,"planDisplayName":"Ultra","onDemandEnabled":false,"showWarning":false,"planUsedCents":24041}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        XCTAssertEqual(decoded.planDisplayName, "Ultra")
        XCTAssertEqual(decoded.planUsedCents, 24041)
        XCTAssertNil(decoded.todaySpendCents)
    }

    func testMenuBarIncludesTodayWhenEnabled() {
        var snap = UsageSnapshot(
            membershipType: "ultra",
            planDisplayName: "Ultra",
            todaySpendCents: 425
        )
        snap.applyDaily(DailyUsageSummary(todayCents: 425))
        var prefs = DisplayPreferences.default
        prefs.menuBarFormat = .detailed
        prefs.menuBar = .init(
            cursorModelsPercent: false,
            otherModelsPercent: false,
            totalPercent: false,
            planSpend: false,
            bonus: false,
            onDemand: false,
            daysRemaining: false,
            burnRateEstimate: true
        )
        let presentation = MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true)
        XCTAssertTrue(presentation.segments.contains(where: { $0.text.contains("$4.25") }))
    }

    private func snapshot(
        plan: Int,
        onDemand: Int = 0,
        start: Date? = nil,
        end: Date? = nil,
        remaining: Int? = nil,
        limit: Int = 40_000
    ) -> UsageSnapshot {
        UsageSnapshot(
            membershipType: "ultra",
            planDisplayName: "Ultra",
            billingCycleStart: start,
            billingCycleEnd: end,
            planUsedCents: plan,
            planLimitCents: limit,
            planRemainingCents: remaining ?? max(0, limit - plan),
            onDemandUsedCents: onDemand
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 15) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
