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
    func testOnTrackWhenSpendMatchesElapsed() throws {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 50)
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            planUsedCents: 10_000,
            planLimitCents: 20_000
        )
        let pace = try XCTUnwrap(snap.pace(now: now))
        XCTAssertEqual(pace.status, .onTrack)
        XCTAssertEqual(pace.projectedCycleEndCents, 20_000, accuracy: 1)
        XCTAssertTrue(pace.caption.contains("On track"))
    }

    func testOverCapWhenProjectionExceedsLimit() throws {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 100)
        let now = Date(timeIntervalSince1970: 25)
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            billingCycleStart: start,
            billingCycleEnd: end,
            planUsedCents: 15_000,
            planLimitCents: 20_000
        )
        let pace = try XCTUnwrap(snap.pace(now: now))
        XCTAssertEqual(pace.status, .overCap)
        XCTAssertTrue(pace.caption.contains("Over cap"))
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
