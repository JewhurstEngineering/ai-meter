import XCTest
@testable import AIMeterCore

final class ProviderUsageMapperTests: XCTestCase {
    func testClaudeMapperReadsRollingWindowsAndExtraUsage() throws {
        let data = try fixture("claude_oauth_usage.json")
        let snap = try ClaudeUsageMapper.map(data)

        XCTAssertEqual(snap.provider, .claude)
        XCTAssertEqual(snap.planDisplayName, "Claude Max")
        XCTAssertEqual(snap.windows.map(\.id), ["session", "weekly", "seven_day_opus"])
        XCTAssertEqual(snap.windows.first { $0.role == .session }?.percentUsed ?? 0, 42, accuracy: 0.01)
        XCTAssertEqual(snap.windows.first { $0.role == .weekly }?.percentUsed ?? 0, 18, accuracy: 0.01)
        XCTAssertEqual(snap.windows.first { $0.id == "seven_day_opus" }?.percentUsed ?? 0, 55, accuracy: 0.01)
        XCTAssertNotNil(snap.windows.first?.resetsAt)
        XCTAssertEqual(snap.spend?.title, "Extra usage")
        XCTAssertEqual(snap.spend?.usedCents, 1250)
        XCTAssertEqual(snap.spend?.limitCents, 5000)
        XCTAssertTrue(snap.spend?.enabled == true)
    }

    func testClaudeUtilizationOneIsOnePercentNotOneHundred() throws {
        let json = """
        {"five_hour":{"utilization":1.0,"resets_at":"2026-08-15T01:00:00.000Z"},"seven_day":{"utilization":0.4}}
        """.data(using: .utf8)!
        let snap = try ClaudeUsageMapper.map(json)
        XCTAssertEqual(snap.windows.first { $0.role == .session }?.percentUsed ?? 0, 1, accuracy: 0.01)
        XCTAssertEqual(snap.windows.first { $0.role == .weekly }?.percentUsed ?? 0, 0.4, accuracy: 0.01)
    }

    func testCodexMapperReadsWindowsCreditsAndExtras() throws {
        let data = try fixture("codex_wham_usage.json")
        let snap = try CodexUsageMapper.map(data)

        XCTAssertEqual(snap.provider, .codex)
        XCTAssertEqual(snap.planDisplayName, "ChatGPT Plus")
        XCTAssertEqual(snap.windows.first { $0.role == .session }?.percentUsed, 34)
        XCTAssertEqual(snap.windows.first { $0.role == .weekly }?.percentUsed, 37)
        XCTAssertTrue(snap.windows.contains { $0.role == .extra && $0.title.contains("Spark") })
        XCTAssertEqual(snap.spend?.title, "Credits")
        XCTAssertEqual(snap.spend?.remainingCents, 539)
        XCTAssertTrue(snap.spend?.enabled == true)
        XCTAssertNotNil(snap.nextResetAt)
    }

    func testAccountRegistryDecodesMissingProviderAsCursor() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","email":"a@b.com","label":"","createdAt":0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let connection = try decoder.decode(AccountConnection.self, from: json)
        XCTAssertEqual(connection.provider, .cursor)
        XCTAssertEqual(connection.displayLabel, "a")
        XCTAssertFalse(connection.isHidden)
        XCTAssertFalse(connection.isPaused)
    }

    func testNormalizeActiveSkipsHiddenAccounts() {
        let hidden = AccountConnection(id: UUID(), email: "a@b.com", isHidden: true)
        let visible = AccountConnection(id: UUID(), email: "b@b.com")
        let registry = AccountRegistry(connections: [hidden, visible], activeAccountID: hidden.id)
        XCTAssertEqual(registry.activeAccountID, visible.id)

        let onlyHidden = AccountRegistry(connections: [hidden], activeAccountID: hidden.id)
        XCTAssertNil(onlyHidden.activeAccountID)
    }

    func testVisibleAndMonitoredAccountCounts() {
        let hidden = AccountConnection(isHidden: true)
        let paused = AccountConnection(isPaused: true)
        let live = AccountConnection()
        let connections = [hidden, paused, live]
        XCTAssertEqual(connections.filter { !$0.isHidden }.map(\.id), [paused.id, live.id])
        XCTAssertEqual(connections.filter { !$0.isPaused }.map(\.id), [hidden.id, live.id])
    }

    func testPausedAccountSkipsNotifications() throws {
        var prefs = try JSONDecoder().decode(DisplayPreferences.self, from: Data("{}".utf8))
        prefs.notificationsEnabled = true
        XCTAssertTrue(UsageNotificationService.allowsNotifications(preferences: prefs, connection: AccountConnection()))
        XCTAssertFalse(
            UsageNotificationService.allowsNotifications(
                preferences: prefs,
                connection: AccountConnection(isPaused: true)
            )
        )
        prefs.notificationsEnabled = false
        XCTAssertFalse(UsageNotificationService.allowsNotifications(preferences: prefs, connection: AccountConnection()))
    }

    func testUnlabeledConnectionUsesProviderName() {
        let claude = AccountConnection(provider: .claude)
        XCTAssertEqual(claude.displayLabel, "Claude")
        XCTAssertEqual(AccountConnection(provider: .codex).displayLabel, "Codex")
    }

    func testClaudeCredentialJSONParse() {
        let raw = """
        {"claudeAiOauth":{"accessToken":"sk-ant-oat-test","refreshToken":"refresh","expiresAt":1893456000000}}
        """
        let cred = ClaudeLocalAuthReader.parseJSON(raw, source: "test")
        XCTAssertEqual(cred?.accessToken, "sk-ant-oat-test")
        XCTAssertEqual(cred?.refreshToken, "refresh")
        XCTAssertNotNil(cred?.expiresAt)
    }

    func testCodexAuthJSONParse() throws {
        let data = """
        {"tokens":{"access_token":"at","refresh_token":"rt","account_id":"acct_1"},"email":"user@example.com"}
        """.data(using: .utf8)!
        let cred = try XCTUnwrap(CodexLocalAuthReader.parse(data, source: "test"))
        XCTAssertEqual(cred.accessToken, "at")
        XCTAssertEqual(cred.refreshToken, "rt")
        XCTAssertEqual(cred.accountID, "acct_1")
        XCTAssertEqual(cred.email, "user@example.com")
    }

    func testHTTP429KeepsLastNumbersCopy() {
        XCTAssertEqual(
            ProviderUsageError.httpStatus(429).errorDescription,
            "Too many usage checks (HTTP 429). Last numbers are kept — try again in a minute."
        )
        XCTAssertTrue(ProviderUsageError.httpStatus(429).keepsLastNumbers)
        XCTAssertTrue(ProviderUsageError.httpStatus(503).keepsLastNumbers)
        XCTAssertTrue(ProviderUsageError.emptyResponse.keepsLastNumbers)
        XCTAssertFalse(ProviderUsageError.unauthorized.keepsLastNumbers)
        XCTAssertTrue(PersonalAPIError.httpStatus(429).keepsLastNumbers)
        XCTAssertFalse(PersonalAPIError.unauthorized.keepsLastNumbers)
    }

    func testClaudeUserAgentUsesInstalledVersion() {
        XCTAssertEqual(ClaudeCodeVersion.userAgent(installed: "2.1.233"), "claude-code/2.1.233")
        XCTAssertEqual(ClaudeCodeVersion.userAgent(installed: nil), "claude-code/\(ClaudeCodeVersion.fallback)")
    }

    func testParseClaudeCodeVersionStrings() {
        XCTAssertEqual(ClaudeCodeVersion.parse("2.1.233 (Claude Code)"), "2.1.233")
        XCTAssertEqual(ClaudeCodeVersion.parse("/Users/me/.local/share/claude/versions/2.1.240"), "2.1.240")
        XCTAssertEqual(ClaudeCodeVersion.parse("v2.1.9"), "2.1.9")
        XCTAssertNil(ClaudeCodeVersion.parse("not-a-version"))
    }

    func testClaudeCodeVersionSort() {
        XCTAssertTrue(ClaudeCodeVersion.isNewer("2.1.94", "2.1.233"))
        XCTAssertFalse(ClaudeCodeVersion.isNewer("2.1.233", "2.1.94"))
    }

    #if os(macOS)
    func testReadsClaudeCodeVersionFromNativeBinaryWhenPresent() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/bin/claude")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let version = ClaudeCodeVersion.version(fromBinary: url)
        XCTAssertNotNil(version)
        XCTAssertEqual(ClaudeCodeVersion.detectInstalled(), version)
        XCTAssertEqual(ClaudeCodeVersion.userAgent(), "claude-code/\(version!)")
    }

    func testPackageJSONMustBeClaudeCode() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let other = dir.appendingPathComponent("package.json")
        try Data("{\"name\":\"unrelated\",\"version\":\"9.9.9\"}".utf8).write(to: other)
        XCTAssertNil(ClaudeCodeVersion.version(fromPackageJSON: other))
        try Data("{\"name\":\"@anthropic-ai/claude-code\",\"version\":\"2.1.250\"}".utf8).write(to: other)
        XCTAssertEqual(ClaudeCodeVersion.version(fromPackageJSON: other), "2.1.250")
    }
    #endif

    private func fixture(_ name: String) throws -> Data {
        let fixtures = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(name)
        return try Data(contentsOf: fixtures)
    }
}
