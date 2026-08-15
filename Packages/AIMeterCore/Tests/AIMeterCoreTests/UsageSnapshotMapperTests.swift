import XCTest
import SQLite3
@testable import AIMeterCore

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
        XCTAssertEqual(snap.modelBreakdown.first?.inputTokens, 2_421_899)
        XCTAssertEqual(snap.modelBreakdown.first?.outputTokens, 1_940_439)
        XCTAssertEqual(snap.provider, .cursor)
        XCTAssertEqual(snap.windows.map(\.id), ["cursor_models", "other_models", "total_included"])
        XCTAssertEqual(snap.windows.first { $0.role == .otherModels }?.percentUsed ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(snap.spend?.title, "On-demand")
        XCTAssertEqual(snap.totalInputTokens, 13_547_525)
        XCTAssertEqual(snap.totalOutputTokens, 2_885_782)
        XCTAssertEqual(MenuBarFormatter.tokenCaption(snap.modelBreakdown[0]), "2.4M in · 1.9M out")
        XCTAssertEqual(MenuBarFormatter.compactCount(940_605), "940.6K")
        XCTAssertEqual(snap.subscriptionStatus, "active")
        XCTAssertFalse(snap.lastPaymentFailed)
        XCTAssertFalse(snap.isYearlyPlan)
        XCTAssertEqual(snap.customerBalanceCents, 0)
        XCTAssertFalse(snap.isTeamMember)
        XCTAssertFalse(snap.isOnStudentPlan)
        XCTAssertFalse(snap.verifiedStudent)
        XCTAssertFalse(snap.trialEligible)
        XCTAssertNil(snap.pendingCancellationDate)
        XCTAssertNil(Mirror(reflecting: stripe).children.first { $0.label == "paymentId" })
    }

    func testBillingCycleWindowMathMatchesAnniversaryCycle() throws {
        let start = try XCTUnwrap(isoDate("2026-08-12T18:28:08.000Z"))
        let end = try XCTUnwrap(isoDate("2026-09-12T18:28:08.000Z"))
        let windows = BillingCycleHistory.previousWindows(start: start, end: end, count: 2)
        XCTAssertEqual(windows.count, 2)
        XCTAssertEqual(windows[0].end, start)
        XCTAssertEqual(windows[0].start, try XCTUnwrap(isoDate("2026-07-12T18:28:08.000Z")))
        XCTAssertEqual(windows[1].end, windows[0].start)
        XCTAssertEqual(windows[1].start, try XCTUnwrap(isoDate("2026-06-11T18:28:08.000Z")))
        for window in windows {
            XCTAssertNotEqual(BillingCycleHistory.aggregatedDateMillis(window.start), "0")
            XCTAssertNotEqual(BillingCycleHistory.aggregatedDateMillis(window.end), "0")
        }
        XCTAssertEqual(
            BillingCycleHistory.aggregatedDateMillis(start),
            String(Int64((start.timeIntervalSince1970 * 1000).rounded()))
        )
    }

    func testCycleWalkStopsAfterTwoEmptyResponses() async {
        let start = Date(timeIntervalSince1970: 1_786_550_888)
        let end = start.addingTimeInterval(31 * 24 * 60 * 60)
        var fetched: [(Date, Date)] = []
        let result = await BillingCycleHistory.walkPrevious(
            currentStart: start,
            currentEnd: end,
            cached: CachedCycleHistory()
        ) { windowStart, windowEnd in
            fetched.append((windowStart, windowEnd))
            return .empty
        }
        XCTAssertEqual(fetched.count, 2)
        XCTAssertTrue(result.reachedEnd)
        XCTAssertTrue(result.cycles.isEmpty)
        XCTAssertEqual(result.fetchedWindows, 2)
        XCTAssertFalse(fetched.contains(where: { $0.0.timeIntervalSince1970 == 0 }))
    }

    func testCycleWalkKeepsSpendAndStopsOnEmptyStreak() async throws {
        let start = try XCTUnwrap(isoDate("2026-08-12T18:28:08.000Z"))
        let end = try XCTUnwrap(isoDate("2026-09-12T18:28:08.000Z"))
        let prev1 = BillingCycleHistory.previousWindows(start: start, end: end, count: 1)[0]
        let result = await BillingCycleHistory.walkPrevious(
            currentStart: start,
            currentEnd: end,
            cached: CachedCycleHistory()
        ) { windowStart, _ in
            if abs(windowStart.timeIntervalSince(prev1.start)) < 2 {
                return .spend(.init(start: windowStart, end: start, totalCents: 16933, modelCount: 3))
            }
            return .empty
        }
        XCTAssertEqual(result.cycles.count, 1)
        XCTAssertEqual(result.cycles.first?.totalCents, 16933)
        XCTAssertEqual(result.fetchedWindows, 3)
        XCTAssertTrue(result.reachedEnd)
    }

    func testCycleWalkUsesCacheAndDoesNotRefetch() async throws {
        let start = try XCTUnwrap(isoDate("2026-08-12T18:28:08.000Z"))
        let end = try XCTUnwrap(isoDate("2026-09-12T18:28:08.000Z"))
        let prev = BillingCycleHistory.previousWindows(start: start, end: end, count: 1)[0]
        let cachedCycle = UsageSnapshot.BillingCycleSpend(
            start: prev.start,
            end: prev.end,
            totalCents: 49858,
            modelCount: 4
        )
        var fetched = 0
        let result = await BillingCycleHistory.walkPrevious(
            currentStart: start,
            currentEnd: end,
            cached: CachedCycleHistory(cycles: [cachedCycle], reachedEnd: true)
        ) { _, _ in
            fetched += 1
            return .empty
        }
        XCTAssertEqual(fetched, 0)
        XCTAssertEqual(result.cycles.count, 1)
        XCTAssertEqual(result.cycles.first?.totalCents, 49858)
    }

    func testMergedHistoryMarksCurrentAndDropsDuplicate() {
        let currentStart = Date(timeIntervalSince1970: 100)
        let currentEnd = Date(timeIntervalSince1970: 200)
        let previous = UsageSnapshot.BillingCycleSpend(
            start: Date(timeIntervalSince1970: 0),
            end: currentStart,
            totalCents: 50,
            modelCount: 1,
            isCurrent: true
        )
        let current = UsageSnapshot.BillingCycleSpend(
            start: currentStart,
            end: currentEnd,
            totalCents: 99,
            modelCount: 2,
            isCurrent: true
        )
        let merged = BillingCycleHistory.mergedHistory(current: current, previous: [previous])
        XCTAssertEqual(merged.count, 2)
        XCTAssertFalse(merged[0].isCurrent)
        XCTAssertTrue(merged[1].isCurrent)
        XCTAssertEqual(merged[1].totalCents, 99)
    }

    func testCycleComparisonCaption() {
        let prev = UsageSnapshot.BillingCycleSpend(
            start: Date(timeIntervalSince1970: 0),
            end: Date(timeIntervalSince1970: 100),
            totalCents: 169_33,
            modelCount: 3
        )
        let current = UsageSnapshot.BillingCycleSpend(
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 200),
            totalCents: 522_01,
            modelCount: 12,
            isCurrent: true
        )
        let snap = UsageSnapshot(
            membershipType: "ultra",
            planDisplayName: "Ultra",
            billingCycleStart: current.start,
            billingCycleEnd: current.end,
            cycleHistory: [prev, current],
            totalModelCostCents: 522_01
        )
        XCTAssertEqual(snap.cycleComparisonCaption, "Last cycle $169 · this cycle $522")
        XCTAssertFalse(snap.hasBillingAlert)
        var failed = snap
        failed.lastPaymentFailed = true
        XCTAssertTrue(failed.hasBillingAlert)
    }

    private func isoDate(_ string: String) -> Date? {
        UsageSnapshotMapper.parseDate(string)
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

        let claude = UsageSnapshot(
            membershipType: "max",
            planDisplayName: "Claude Max",
            provider: .claude,
            windows: [
                .init(id: "session", title: "5-hour", percentUsed: 44, kind: .rolling, role: .session),
                .init(id: "weekly", title: "7-day", percentUsed: 20, kind: .rolling, role: .weekly),
            ]
        )
        let mixed = MenuBarFormatter.formatCombined(
            entries: [
                (label: "Cursor", snapshot: work, authenticated: true),
                (label: "Claude", snapshot: claude, authenticated: true),
            ],
            preferences: prefs
        )
        XCTAssertEqual(mixed.segments.map(\.text), ["Cursor 12%", "Claude 20%"])
        XCTAssertFalse(mixed.showWarningDot)

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

    func testWidgetSnapshotTransferPayloadRoundTrip() throws {
        let snap = UsageSnapshot(
            membershipType: "pro",
            planDisplayName: "Pro",
            otherModelsPercentUsed: 41,
            planUsedCents: 1200,
            planLimitCents: 2000
        )
        let widget = WidgetSnapshot(from: snap, warnings: .default)
        let data = try WidgetSnapshotStore.data(from: widget)
        let decoded = WidgetSnapshotStore.snapshot(from: data)
        XCTAssertEqual(decoded?.planDisplayName, "Pro")
        XCTAssertEqual(decoded?.otherModelsPercentUsed ?? 0, 41, accuracy: 0.01)
        XCTAssertEqual(WidgetSnapshotStore.watchTransferKey, "widgetSnapshotJSON")
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

    func testCompactTokenFormatting() {
        XCTAssertEqual(MenuBarFormatter.compactCount(999), "999")
        XCTAssertEqual(MenuBarFormatter.compactCount(1_000), "1K")
        XCTAssertEqual(MenuBarFormatter.compactCount(12_400), "12.4K")
        XCTAssertEqual(MenuBarFormatter.compactCount(2_421_899), "2.4M")
        XCTAssertNil(MenuBarFormatter.tokenCaption(input: nil, output: nil))
        XCTAssertEqual(MenuBarFormatter.tokenCaption(input: 100, output: nil), "100 in")
    }

    #if os(macOS)
    func testLocalComposerHeadersJSON() throws {
        let json = """
        {
          "allComposers": [
            {
              "composerId": "abc-123",
              "name": "Fix login",
              "unifiedMode": "agent",
              "lastUpdatedAt": 1737316260000,
              "modelConfig": { "modelName": "composer-1" },
              "workspaceIdentifier": {
                "id": "ws1",
                "uri": { "fsPath": "/Users/me/Projects/my-app" }
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let rows = CursorLocalComposerReader.decodeHeadersJSON(json)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.name, "Fix login")
        XCTAssertEqual(rows.first?.modeLabel, "Agent")
        XCTAssertEqual(rows.first?.model, "composer-1")
        XCTAssertEqual(rows.first?.projectFolder, "my-app")
    }

    func testLocalComposerSkipsDraftsAndUsesCheckpointTime() throws {
        let json = """
        {
          "composerId": "abc-123",
          "name": "Fix login",
          "unifiedMode": "agent",
          "createdAt": 1000,
          "lastUpdatedAt": 2000,
          "conversationCheckpointLastUpdatedAt": 1786650993746,
          "isDraft": false,
          "modelConfig": { "modelName": "grok-4.6" },
          "workspaceIdentifier": { "uri": { "fsPath": "/Users/me/Projects/my-app" } }
        }
        """.data(using: .utf8)!
        let row = CursorLocalComposerReader.decodeComposerData(json)
        XCTAssertEqual(row?.name, "Fix login")
        XCTAssertEqual(row?.model, "grok-4.6")
        XCTAssertEqual(row?.updatedAt?.timeIntervalSince1970 ?? 0, 1_786_650_993.746, accuracy: 0.01)

        let draft = """
        { "composerId": "d1", "name": "scratch", "isDraft": true, "createdAt": 999999 }
        """.data(using: .utf8)!
        XCTAssertNil(CursorLocalComposerReader.decodeComposerData(draft))
    }

    func testCLIModeLabel() {
        let cli = LocalComposerSummary(id: "1", name: "Refactor", mode: "plan", source: "cli")
        XCTAssertEqual(cli.modeLabel, "CLI · Plan")
        XCTAssertEqual(cli.activityModeLabel, "Plan")
        XCTAssertTrue(cli.isCLI)
        let ask = LocalComposerSummary(id: "2", name: "Why", mode: "ask", source: "cli")
        XCTAssertEqual(ask.modeLabel, "CLI · Ask")
        XCTAssertEqual(ask.activityModeLabel, "Ask")
        let agent = LocalComposerSummary(id: "3", name: "Do it", source: "cli")
        XCTAssertEqual(agent.modeLabel, "CLI")
        XCTAssertEqual(agent.activityModeLabel, "Agent")
    }

    func testCLIMetaJSONAndHex() throws {
        let json = """
        {"name":"New Agent","mode":"plan","createdAt":1761698454965}
        """
        let parsed = try XCTUnwrap(CursorCLISessionReader.decodeMetaJSON(Data(json.utf8)))
        XCTAssertEqual(parsed.name, "New Agent")
        XCTAssertEqual(parsed.mode, "plan")

        let hex = Data(json.utf8).map { String(format: "%02x", $0) }.joined()
        let fromHex = try XCTUnwrap(CursorCLISessionReader.decodeMetaValue(hex))
        XCTAssertEqual(fromHex.name, "New Agent")
        XCTAssertEqual(fromHex.mode, "plan")
    }

    func testCLIRecentSessionsFromStore() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cli-chats-\(UUID().uuidString)", isDirectory: true)
        let projects = root.appendingPathComponent("projects", isDirectory: true)
        let chats = root.appendingPathComponent("chats", isDirectory: true)
        let hash = CursorCLISessionReader.md5Hex("/Users/me/Projects/demo-app")
        let chatID = "EF886E42-25B4-4A52-92BF-881D6FC4232E"
        let storeDir = chats.appendingPathComponent(hash).appendingPathComponent(chatID)
        try FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        let storeURL = storeDir.appendingPathComponent("store.db")
        try writeCLIStore(
            at: storeURL,
            json: #"{"name":"Fix login","mode":"ask","createdAt":1761698454965}"#
        )

        let rows = CursorCLISessionReader.recent(limit: 4, chatsRoot: chats, projectsRoot: projects)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.name, "Fix login")
        XCTAssertEqual(rows.first?.modeLabel, "CLI · Ask")
        XCTAssertEqual(rows.first?.id.lowercased(), chatID.lowercased())
        try? FileManager.default.removeItem(at: root)
    }

    func testCursorAgentExecutablePaths() {
        XCTAssertTrue(CursorProcessMonitor.isCursorAgentExecutable(path: "/Users/me/.local/share/cursor-agent/versions/1/cursor-agent"))
        XCTAssertTrue(CursorProcessMonitor.isCursorAgentExecutable(path: "/opt/homebrew/bin/cursor-agent"))
        XCTAssertTrue(CursorProcessMonitor.isCursorAgentExecutable(path: "/tmp/cursor-agent/agent"))
        XCTAssertFalse(CursorProcessMonitor.isCursorAgentExecutable(path: "/Applications/Cursor.app/Contents/MacOS/Cursor"))
        XCTAssertFalse(CursorProcessMonitor.isCursorAgentExecutable(path: "/usr/bin/agent"))
    }

    func testCLIInstallVersionFromSymlinkLayout() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cli-install-\(UUID().uuidString)", isDirectory: true)
        let versionDir = root.appendingPathComponent("versions/2026.08.04-aaa8809", isDirectory: true)
        try FileManager.default.createDirectory(at: versionDir, withIntermediateDirectories: true)
        let binary = versionDir.appendingPathComponent("cursor-agent")
        FileManager.default.createFile(atPath: binary.path, contents: Data())
        let link = root.appendingPathComponent("cursor-agent")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: binary.path)
        let version = CursorProcessMonitor.versionFromCLIBinary(link)
        XCTAssertEqual(version, "2026.08.04-aaa8809")
        let install = CursorProcessMonitor.installedCLI(extraBinaryURLs: [link])
        XCTAssertTrue(install.installed)
        XCTAssertEqual(install.version, "2026.08.04-aaa8809")
        try? FileManager.default.removeItem(at: root)
    }

    func testThisMacSummariesSplitEditorAndCLI() {
        let both = CursorProcessSnapshot(
            appCount: 1,
            windowCount: 3,
            cliProcessCount: 2,
            cliInstalled: true,
            cliVersion: "2026.08.04-aaa8809"
        )
        XCTAssertEqual(both.summaryLine, "Cursor · 3 windows")
        XCTAssertEqual(both.cliSummaryLine, "CLI · 2026.08.04-aaa8809")
        XCTAssertTrue(both.showsCLIRow)
        XCTAssertTrue(both.cliRunning)

        let idle = CursorProcessSnapshot(cliInstalled: true)
        XCTAssertEqual(idle.summaryLine, "Cursor not running")
        XCTAssertEqual(idle.cliSummaryLine, "CLI not running")

        let missing = CursorProcessSnapshot()
        XCTAssertFalse(missing.showsCLIRow)
        XCTAssertEqual(missing.cliSummaryLine, "CLI not installed")
    }

    private func writeCLIStore(at url: URL, json: String) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK else {
            throw NSError(domain: "cli-test", code: 1)
        }
        defer { sqlite3_close(db) }
        guard sqlite3_exec(db, "CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT);", nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "cli-test", code: 2)
        }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO meta (key, value) VALUES ('0', ?);", -1, &statement, nil) == SQLITE_OK else {
            throw NSError(domain: "cli-test", code: 3)
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, json, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw NSError(domain: "cli-test", code: 4)
        }
    }
    #endif

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
