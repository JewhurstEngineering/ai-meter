import XCTest
@testable import AIMeterCore

final class PersonalAPIErrorTests: XCTestCase {
    func testHTTP204IsNotUnauthorized() {
        XCTAssertEqual(PersonalAPIError.from(httpStatus: 204), .emptyResponse)
        XCTAssertNotEqual(PersonalAPIError.from(httpStatus: 204), .unauthorized)
        XCTAssertEqual(PersonalAPIError.from(httpStatus: 401), .unauthorized)
        XCTAssertEqual(PersonalAPIError.from(httpStatus: 500), .httpStatus(500))
    }

    func testLocalizedCopy() {
        XCTAssertEqual(PersonalAPIError.unauthorized.errorDescription, "Session expired — sign in again.")
        XCTAssertTrue(PersonalAPIError.decodingFailed.errorDescription?.contains("usage API changed") == true)
        XCTAssertTrue(PersonalAPIError.emptyResponse.errorDescription?.contains("empty") == true)
        XCTAssertTrue(PersonalAPIError.httpStatus(503).errorDescription?.contains("503") == true)
    }

    func testSessionExpiredKeepsSnapshotAndCloudKey() {
        let snap = UsageSnapshot(membershipType: "ultra", planDisplayName: "Ultra", planUsedCents: 1000)
        var runtime = AccountRuntime(
            connection: AccountConnection(email: "a@example.com", label: "work"),
            snapshot: snap,
            lastError: nil,
            isAuthenticated: true,
            hasCloudAPIKey: true,
            cloudAPIKeyName: "agents"
        )
        runtime.markSessionExpired()
        XCTAssertFalse(runtime.isAuthenticated)
        XCTAssertEqual(runtime.snapshot?.planUsedCents, 1000)
        XCTAssertTrue(runtime.hasCloudAPIKey)
        XCTAssertEqual(runtime.cloudAPIKeyName, "agents")
        XCTAssertEqual(runtime.lastError, PersonalAPIError.unauthorized.errorDescription)
        XCTAssertTrue(runtime.needsReauthentication)
    }
}

final class BurnRateTests: XCTestCase {
    private var calendar: Calendar { Calendar.current }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func spendDays(from start: Date, cents: [Double]) -> [UsageSnapshot.DailySpend] {
        cents.enumerated().map { offset, value in
            let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: start))!
            return .init(day: day, cents: value)
        }
    }

    func testTooSoonOnFirstDay() throws {
        let start = date(2026, 8, 1)
        let end = date(2026, 8, 31)
        let now = date(2026, 8, 1, hour: 18)
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            dailySpend: spendDays(from: start, cents: [29_700]),
            planUsedCents: 29_700,
            planLimitCents: 40_000
        )
        let pace = try XCTUnwrap(snap.pace(now: now, calendar: calendar))
        XCTAssertEqual(pace.status, .onTrack)
        XCTAssertEqual(pace.projectedCycleEndCents, 29_700, accuracy: 1)
        XCTAssertTrue(pace.caption.contains("too soon to pace"))
        XCTAssertFalse(pace.caption.contains("Over cap"))
    }

    func testOverCapOnFirstDayWhenAlreadyOverLimit() throws {
        let start = date(2026, 8, 1)
        let end = date(2026, 8, 31)
        let now = date(2026, 8, 1, hour: 18)
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            dailySpend: spendDays(from: start, cents: [50_000]),
            planUsedCents: 50_000,
            planLimitCents: 40_000
        )
        let pace = try XCTUnwrap(snap.pace(now: now, calendar: calendar))
        XCTAssertEqual(pace.status, .overCap)
        XCTAssertEqual(pace.projectedCycleEndCents, 50_000, accuracy: 1)
        XCTAssertTrue(pace.caption.contains("Over cap"))
        XCTAssertTrue(pace.caption.contains("so far"))
    }

    func testSpikeAndQuietDayDoesNotLinearProject() throws {
        let start = date(2026, 8, 1)
        let end = date(2026, 8, 31)
        let now = date(2026, 8, 2, hour: 18)
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            dailySpend: spendDays(from: start, cents: [29_700, 0]),
            planUsedCents: 29_700,
            planLimitCents: 40_000
        )
        let pace = try XCTUnwrap(snap.pace(now: now, calendar: calendar))
        XCTAssertEqual(pace.projectedCycleEndCents, 29_700, accuracy: 1)
        XCTAssertNotEqual(pace.status, .overCap)
        XCTAssertTrue(pace.caption.contains("Typical"))
        let linear = 29_700.0 / (now.timeIntervalSince(start) / end.timeIntervalSince(start))
        XCTAssertGreaterThan(linear, 400_000)
        XCTAssertLessThan(pace.projectedCycleEndCents, linear / 2)
    }

    func testTwoWorkDaysDoNotProjectThousandsMore() throws {
        let start = date(2026, 8, 13)
        let end = date(2026, 9, 13)
        let now = date(2026, 8, 14, hour: 18)
        let snap = UsageSnapshot(
            membershipType: "ultra",
            planDisplayName: "Ultra",
            billingCycleStart: start,
            billingCycleEnd: end,
            dailySpend: spendDays(from: start, cents: [32_200, 8_900]),
            planUsedCents: 40_000,
            planLimitCents: 40_000
        )
        let pace = try XCTUnwrap(snap.pace(now: now, calendar: calendar))
        XCTAssertEqual(pace.projectedCycleEndCents, 40_000, accuracy: 1)
        XCTAssertLessThan(pace.projectedCycleEndCents, 100_000)
        XCTAssertFalse(pace.caption.contains("2814"))
        XCTAssertTrue(pace.caption.contains("Typical ~$0/day"))
    }

    func testThreePlusDropsHighestThenMedian() throws {
        let start = date(2026, 8, 1)
        let end = date(2026, 8, 31)
        let now = date(2026, 8, 4, hour: 18)
        let days: [Double] = [1_000, 2_000, 3_000, 40_000]
        let used = Int(days.reduce(0, +))
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            dailySpend: spendDays(from: start, cents: days),
            planUsedCents: used,
            planLimitCents: 400_000
        )
        let typical = DailySpendHistory.typicalDailyCents(days, elapsedDays: 4)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        let daysLeft = calendar.dateComponents(
            [.day],
            from: tomorrow,
            to: calendar.startOfDay(for: end)
        ).day!
        let expected = Double(used) + (typical ?? 0) * Double(daysLeft)
        let pace = try XCTUnwrap(snap.pace(now: now, calendar: calendar))
        XCTAssertEqual(pace.projectedCycleEndCents, expected, accuracy: 1)
        XCTAssertLessThan(pace.projectedCycleEndCents, 100_000)
        XCTAssertNotEqual(pace.status, .overCap)
    }

    func testOverCapWhenTypicalProjectionExceedsLimit() throws {
        let start = date(2026, 8, 1)
        let end = date(2026, 8, 31)
        let now = date(2026, 8, 7, hour: 18)
        let days = Array(repeating: 1_000.0, count: 7)
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            dailySpend: spendDays(from: start, cents: days),
            planUsedCents: 7_000,
            planLimitCents: 20_000
        )
        let pace = try XCTUnwrap(snap.pace(now: now, calendar: calendar))
        XCTAssertEqual(pace.status, .overCap)
        XCTAssertTrue(pace.caption.contains("Over cap"))
        XCTAssertGreaterThan(pace.projectedCycleEndCents, 20_000)
    }

    func testOnTrackWhenTypicalStaysUnderCap() throws {
        let start = date(2026, 8, 1)
        let end = date(2026, 8, 31)
        let now = date(2026, 8, 7, hour: 12)
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            dailySpend: spendDays(from: start, cents: Array(repeating: 500.0, count: 7)),
            planUsedCents: 3_500,
            planLimitCents: 40_000
        )
        let pace = try XCTUnwrap(snap.pace(now: now, calendar: calendar))
        XCTAssertEqual(pace.status, .onTrack)
        XCTAssertTrue(pace.caption.contains("Typical"))
        XCTAssertLessThan(pace.projectedCycleEndCents, 40_000)
    }

    func testNilBeforeCycleStarts() {
        let start = Date(timeIntervalSince1970: 50)
        let end = Date(timeIntervalSince1970: 100)
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            planUsedCents: 100
        )
        XCTAssertNil(snap.pace(now: Date(timeIntervalSince1970: 0)))
    }

    func testNilWithoutDates() {
        let snap = UsageSnapshot(membershipType: "pro", planDisplayName: "Pro", planUsedCents: 100)
        XCTAssertNil(snap.pace(now: Date()))
    }

    func testNilForClaude() {
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: date(2026, 8, 1),
            billingCycleEnd: date(2026, 8, 31),
            planUsedCents: 1_000,
            planLimitCents: 10_000,
            provider: .claude
        )
        XCTAssertNil(snap.pace(now: date(2026, 8, 10)))
    }
}

final class UsageExportTests: XCTestCase {
    func testCSVContainsSummaryModelsAndCyclesWithoutSecrets() {
        let prev = UsageSnapshot.BillingCycleSpend(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 100),
            totalCents: 1_000,
            modelCount: 1
        )
        let current = UsageSnapshot.BillingCycleSpend(
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 200),
            totalCents: 2_000,
            modelCount: 1,
            isCurrent: true
        )
        let snap = UsageSnapshot(
            membershipType: "ultra",
            planDisplayName: "Ultra",
            billingCycleStart: current.start,
            billingCycleEnd: current.end,
            cycleHistory: [prev, current],
            cursorModelsPercentUsed: 10,
            planUsedCents: 2_000,
            planLimitCents: 40_000,
            modelBreakdown: [.init(model: "claude-x", totalCents: 500)]
        )
        let csv = UsageExport.csv(snap)
        XCTAssertTrue(csv.contains("plan,Ultra"))
        XCTAssertTrue(csv.contains("cursor_models_percent,10.00"))
        XCTAssertTrue(csv.contains("claude-x"))
        XCTAssertTrue(csv.contains("current_"))
        XCTAssertFalse(csv.lowercased().contains("token"))
        XCTAssertFalse(csv.lowercased().contains("cookie"))
        XCTAssertFalse(csv.lowercased().contains("keychain"))
    }

    func testJSONRoundTripFields() throws {
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            planUsedCents: 123,
            modelBreakdown: [.init(model: "m", totalCents: 50)]
        )
        let data = try UsageExport.json(snap)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["plan"] as? String, "Pro")
        XCTAssertEqual(object?["planUsedCents"] as? Int, 123)
        XCTAssertNil(object?["sessionToken"])
        XCTAssertNil(object?["cookie"])
    }
}
