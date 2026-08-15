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

    private func fixture(_ name: String) throws -> Data {
        let fixtures = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(name)
        return try Data(contentsOf: fixtures)
    }
}
