import XCTest
@testable import CursorUsageCore

final class UsageSnapshotMapperTests: XCTestCase {
    func testMapsUltraUsageSummaryPools() throws {
        let summaryData = try fixture("usage_summary_ultra.json")
        let aggData = try fixture("aggregated_usage_ultra.json")
        let stripeData = try fixture("auth_stripe_ultra.json")

        let summary = try JSONDecoder().decode(UsageSummaryResponse.self, from: summaryData)
        let agg = try JSONDecoder().decode(AggregatedUsageResponse.self, from: aggData)
        let stripe = try JSONDecoder().decode(AuthStripeResponse.self, from: stripeData)

        let snap = UsageSnapshotMapper.map(summary: summary, stripe: stripe, aggregated: agg)

        XCTAssertEqual(snap.membershipType, "ultra")
        XCTAssertEqual(snap.planDisplayName, "Ultra")
        XCTAssertEqual(snap.cursorModelsPercentUsed!, 3.817, accuracy: 0.001)
        XCTAssertEqual(snap.otherModelsPercentUsed!, 100, accuracy: 0.001)
        XCTAssertEqual(snap.totalPercentUsed!, 23.0848, accuracy: 0.001)
        XCTAssertEqual(snap.planUsedCents, 40000)
        XCTAssertEqual(snap.planLimitCents, 40000)
        XCTAssertEqual(snap.bonusCents, 17712)
        XCTAssertFalse(snap.onDemandEnabled)
        XCTAssertEqual(snap.modelBreakdown.count, 3)
        XCTAssertEqual(snap.modelBreakdown.first?.model, "claude-fable-5-thinking-high")
    }

    func testMenuBarFormatterDetailed() {
        let snap = UsageSnapshot(
            membershipType: "ultra",
            planDisplayName: "Ultra",
            cursorModelsPercentUsed: 4,
            otherModelsPercentUsed: 61,
            planUsedCents: 40000,
            planLimitCents: 40000,
            bonusCents: 17712,
            onDemandEnabled: false
        )
        var prefs = DisplayPreferences.default
        prefs.menuBarFormat = .detailed
        prefs.menuBar.cursorModelsPercent = true
        prefs.menuBar.otherModelsPercent = true
        prefs.menuBar.planSpend = true
        prefs.menuBar.bonus = true
        prefs.warningThresholdPercent = 95

        let presentation = MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true)
        XCTAssertTrue(presentation.accessibilityTitle.contains("4%") || presentation.segments.contains(where: { $0.text.contains("4%") }))
        XCTAssertTrue(presentation.segments.contains(where: { $0.text.contains("61%") }))
        XCTAssertFalse(presentation.showWarningDot)

        prefs.warningThresholdPercent = 50
        XCTAssertTrue(MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true).showWarningDot)
    }

    func testSessionCookieBuilder() throws {
        // minimal fake JWT with sub user_01ABC (header.payload.sig)
        let payload = Data(#"{"sub":"google-oauth2|user_01ABC"}"#.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        let jwt = "eyJhbGciOiJub25lIn0.\(payload).sig"
        let cookie = try SessionCookieBuilder.cookieValue(fromStoredToken: jwt)
        XCTAssertEqual(cookie, "user_01ABC%3A%3A\(jwt)")
    }

    private func fixture(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name.replacingOccurrences(of: ".json", with: ""), withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
        guard let url else {
            // Fixtures copied as folder — list and load
            let fixtures = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(name)
            return try Data(contentsOf: fixtures)
        }
        return try Data(contentsOf: url)
    }
}
