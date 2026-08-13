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
            planUsedCents: 20000,
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
        prefs.menuBarWarnings = .init(
            cursorModelsPercent: 95,
            otherModelsPercent: 95,
            onDemandAndLimitsPercent: 95,
            totalIncludedPercent: 95
        )

        let presentation = MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true)
        XCTAssertTrue(presentation.accessibilityTitle.contains("4%") || presentation.segments.contains(where: { $0.text.contains("4%") }))
        XCTAssertTrue(presentation.segments.contains(where: { $0.text.contains("61%") }))
        XCTAssertFalse(presentation.showWarningDot)

        prefs.menuBarWarnings.otherModelsPercent = 50
        let warned = MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true)
        XCTAssertTrue(warned.showWarningDot)
        XCTAssertTrue(warned.accessibilityTitle.contains("Other Models"))
        XCTAssertTrue(warned.accessibilityTitle.contains("alert set to 50%"))
        XCTAssertTrue(warned.warningHits.contains(where: { $0.channel == .otherModels }))
        XCTAssertEqual(
            warned.warningHits.first(where: { $0.channel == .otherModels })?.compactLine,
            "Other 61% @ 50%"
        )

        prefs.menuBarWarnings.cursorModelsPercent = 3
        let multi = MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true)
        XCTAssertEqual(Set(multi.warningHits.map(\.channel)), [.cursorModels, .otherModels])

        prefs.snoozedWarningChannels = [UsageSnapshot.WarningChannel.otherModels.rawValue]
        let snoozed = MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true)
        XCTAssertEqual(snoozed.warningHits.map(\.channel), [.cursorModels])
        XCTAssertTrue(snoozed.showWarningDot)

        prefs.snoozedWarningChannels = [
            UsageSnapshot.WarningChannel.cursorModels.rawValue,
            UsageSnapshot.WarningChannel.otherModels.rawValue,
        ]
        let cleared = MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true)
        XCTAssertTrue(cleared.warningHits.isEmpty)
        XCTAssertFalse(cleared.showWarningDot)

        prefs.menuBarWarnings.otherModelsPercent = 95
        prefs.menuBarWarnings.onDemandAndLimitsPercent = 40
        // plan used 50% of limit → warns on limits channel
        XCTAssertTrue(MenuBarFormatter.format(snapshot: snap, preferences: prefs, authenticated: true).showWarningDot)
    }

    func testMenuBarFormatterCombinedPrefixesLabels() {
        let work = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            cursorModelsPercentUsed: 12,
            otherModelsPercentUsed: 12
        )
        let personal = UsageSnapshot(
            membershipType: "ultra",
            planDisplayName: "Ultra",
            cursorModelsPercentUsed: 4,
            otherModelsPercentUsed: 88
        )
        var prefs = DisplayPreferences.default
        prefs.menuBarAccountMode = .combined
        prefs.menuBar.otherModelsPercent = true

        let presentation = MenuBarFormatter.formatCombined(
            entries: [
                (label: "work", snapshot: work, authenticated: true),
                (label: "personal", snapshot: personal, authenticated: true),
            ],
            preferences: prefs
        )
        XCTAssertEqual(presentation.segments.map(\.text), ["work 12%", "personal 88%"])
        XCTAssertFalse(presentation.showWarningDot)

        prefs.menuBarWarnings.otherModelsPercent = 80
        let warned = MenuBarFormatter.formatCombined(
            entries: [
                (label: "work", snapshot: work, authenticated: true),
                (label: "personal", snapshot: personal, authenticated: true),
            ],
            preferences: prefs
        )
        XCTAssertTrue(warned.showWarningDot)
        XCTAssertTrue(warned.warningHits.contains(where: { $0.channel == .otherModels }))
    }

    func testAccountLegacyMigrationPlansUUIDConnection() {
        let empty = AccountRegistry.empty
        XCTAssertNil(AccountRegistryStore.planLegacyMigration(existing: empty, legacyTokenPresent: false))

        let planned = AccountRegistryStore.planLegacyMigration(existing: empty, legacyTokenPresent: true)
        XCTAssertEqual(planned?.connections.count, 1)
        XCTAssertEqual(planned?.activeAccountID, planned?.connections.first?.id)

        var filled = AccountRegistry.empty
        filled.connections = [AccountConnection(email: "a@b.com")]
        filled.normalizeActive()
        XCTAssertNil(AccountRegistryStore.planLegacyMigration(existing: filled, legacyTokenPresent: true))
    }

    func testAccountDisplayLabelUsesEmailLocalPart() {
        let unnamed = AccountConnection(email: "james@shift.example")
        XCTAssertEqual(unnamed.displayLabel, "james")
        XCTAssertEqual(unnamed.menuBarLabel, "james")
        var labeled = unnamed
        labeled.label = "Work Ultra"
        XCTAssertEqual(labeled.displayLabel, "Work Ultra")
        XCTAssertEqual(labeled.menuBarLabel, "Work Ultra")
    }

    func testWidgetSnapshotRoundTrip() throws {
        let snap = UsageSnapshot(
            membershipType: "ultra",
            planDisplayName: "Ultra",
            billingCycleEnd: Date(timeIntervalSince1970: 1_789_200_000),
            cursorModelsPercentUsed: 3,
            otherModelsPercentUsed: 37,
            totalPercentUsed: 10,
            planUsedCents: 24041,
            planLimitCents: 40000,
            bonusCents: 1200,
            onDemandEnabled: true,
            onDemandUsedCents: 500,
            onDemandLimitCents: 10_000,
            modelBreakdown: [
                .init(model: "claude-fable-5-thinking-high", totalCents: 18602),
                .init(model: "cursor-grok-4.6-high", totalCents: 4604),
            ],
            totalModelCostCents: 23206
        )
        let widget = WidgetSnapshot(from: snap, warnings: .default)
        let data = try JSONEncoder().encode(widget)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded.planDisplayName, "Ultra")
        XCTAssertEqual(decoded.otherModelsPercentUsed!, 37, accuracy: 0.01)
        XCTAssertEqual(decoded.planUsedCents, 24041)
        XCTAssertEqual(decoded.onDemandUsedCents, 500)
        XCTAssertEqual(decoded.onDemandLimitCents, 10_000)
        XCTAssertEqual(decoded.bonusCents, 1200)
        XCTAssertEqual(decoded.modelBreakdown?.count, 2)
        XCTAssertEqual(decoded.modelBreakdown?.first?.model, "claude-fable-5-thinking-high")
        XCTAssertEqual(decoded.totalModelCostCents, 23206)
        XCTAssertFalse(decoded.isOnDemandUnlimited)
        XCTAssertEqual(decoded.billingCycleEnd, Date(timeIntervalSince1970: 1_789_200_000))
    }

    func testLegacyWidgetSnapshotJSONStillDecodes() throws {
        let json = """
        {"generatedAt":0,"planDisplayName":"Ultra","onDemandEnabled":false,"showWarning":false,"planUsedCents":24041}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        XCTAssertEqual(decoded.planDisplayName, "Ultra")
        XCTAssertEqual(decoded.planUsedCents, 24041)
        XCTAssertNil(decoded.onDemandUsedCents)
        XCTAssertNil(decoded.modelBreakdown)
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
