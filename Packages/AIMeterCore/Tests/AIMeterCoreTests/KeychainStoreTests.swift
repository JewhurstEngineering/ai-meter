import XCTest
@testable import AIMeterCore

final class KeychainStoreTests: XCTestCase {
    private var service: String!
    private var account: String!

    override func setUp() {
        super.setUp()
        service = "com.jamesware.aimeter.test.\(UUID().uuidString)"
        account = "account-\(UUID().uuidString)"
    }

    override func tearDown() {
        KeychainStore(service: service, usesDataProtectionKeychain: true).delete(account: account)
        KeychainStore(service: service, usesDataProtectionKeychain: false).delete(account: account)
        super.tearDown()
    }

    func testRoundTrip() throws {
        let store = KeychainStore(service: service)
        try store.save(token: "secret-token", account: account)
        XCTAssertEqual(store.load(account: account), "secret-token")
    }

    func testDefaultStoreWritesLoginKeychain() throws {
        let store = KeychainStore(service: service)
        try store.save(token: "login-token", account: account)
        let loginOnly = KeychainStore(
            service: service,
            usesDataProtectionKeychain: false,
            recoversFromDataProtectionKeychain: false
        )
        XCTAssertEqual(loginOnly.load(account: account), "login-token")
    }

    func testUpdatingTokenDoesNotDeleteBeforeReplacement() throws {
        let store = KeychainStore(service: service)
        try store.save(token: "first-token", account: account)
        try store.save(token: "replacement-token", account: account)
        XCTAssertEqual(store.load(account: account), "replacement-token")
    }

    func testLoadDoesNotDeleteLegacyCopy() throws {
        let legacy = KeychainStore(service: service, usesDataProtectionKeychain: false)
        try legacy.save(token: "legacy-token", account: account)

        let modern = KeychainStore(service: service, usesDataProtectionKeychain: true)
        XCTAssertEqual(modern.load(account: account), "legacy-token")
        XCTAssertEqual(legacy.load(account: account), "legacy-token")
    }

    func testDeleteRemovesItem() throws {
        let store = KeychainStore(service: service)
        try store.save(token: "gone", account: account)
        store.delete(account: account)
        XCTAssertNil(store.load(account: account))
    }
}

final class LocalConnectResultTests: XCTestCase {
    func testSuccessMessageDistinguishesRefresh() {
        let added = LocalConnectResult(
            id: UUID(),
            displayLabel: "Pro",
            source: "~/.codex/auth.json",
            refreshedExisting: false,
            provider: .codex
        )
        XCTAssertEqual(added.successMessage, "Connected Codex (Pro).")
        let refreshed = LocalConnectResult(
            id: added.id,
            displayLabel: "Pro",
            source: added.source,
            refreshedExisting: true,
            provider: .codex
        )
        XCTAssertEqual(refreshed.successMessage, "Refreshed Codex (Pro).")
    }

    func testLoginInstructionsNameProviderCommands() {
        XCTAssertTrue(CodexLocalAuthReader.loginInstructions.contains("codex login"))
        XCTAssertTrue(ClaudeLocalAuthReader.loginInstructions.contains("claude"))
    }
}

final class ClaudeLocalAuthReaderTests: XCTestCase {

    // MARK: - date() numeric formats

    func testDateParsesUnixSeconds() {
        let ts = 1_750_000_000.0
        let json = "{\"accessToken\":\"tok\",\"expiresAt\":\(ts)}"
        let cred = ClaudeLocalAuthReader.parseJSON(json, source: "test")
        XCTAssertNotNil(cred?.expiresAt)
        XCTAssertEqual(cred?.expiresAt?.timeIntervalSince1970 ?? 0, ts, accuracy: 1)
    }

    func testDateParsesUnixMilliseconds() {
        let ms = 1_750_000_000_000.0
        let expectedSec = ms / 1000
        let json = "{\"accessToken\":\"tok\",\"expiresAt\":\(ms)}"
        let cred = ClaudeLocalAuthReader.parseJSON(json, source: "test")
        XCTAssertNotNil(cred?.expiresAt)
        XCTAssertEqual(cred?.expiresAt?.timeIntervalSince1970 ?? 0, expectedSec, accuracy: 1)
    }

    // MARK: - date() ISO 8601 (regression for Bug B)
    // Before the fix, these returned nil, making needsRefresh always false
    // so stale Claude tokens were never refreshed proactively.

    func testDateParsesISO8601WithoutFractionalSeconds() {
        let json = "{\"accessToken\":\"tok\",\"expiresAt\":\"2026-08-19T15:00:00Z\"}"
        let cred = ClaudeLocalAuthReader.parseJSON(json, source: "test")
        XCTAssertNotNil(cred?.expiresAt, "ISO 8601 expiresAt must be parsed so needsRefresh works")
        let formatter = ISO8601DateFormatter()
        let expected = formatter.date(from: "2026-08-19T15:00:00Z")
        XCTAssertEqual(cred?.expiresAt, expected)
    }

    func testDateParsesISO8601WithFractionalSeconds() {
        let json = "{\"accessToken\":\"tok\",\"expiresAt\":\"2026-08-19T15:00:00.000Z\"}"
        let cred = ClaudeLocalAuthReader.parseJSON(json, source: "test")
        XCTAssertNotNil(cred?.expiresAt, "ISO 8601 with milliseconds must be parsed")
    }

    func testDateStringNumericFallbackStillWorks() {
        let ts = 1_750_000_000.0
        let json = "{\"accessToken\":\"tok\",\"expiresAt\":\"\(Int(ts))\"}"
        let cred = ClaudeLocalAuthReader.parseJSON(json, source: "test")
        XCTAssertNotNil(cred?.expiresAt)
        XCTAssertEqual(cred?.expiresAt?.timeIntervalSince1970 ?? 0, ts, accuracy: 1)
    }

    // MARK: - needsRefresh

    func testNeedsRefreshFalseWhenExpiresAtNil() {
        let cred = ClaudeOAuthCredential(accessToken: "tok", source: "test")
        XCTAssertFalse(cred.needsRefresh, "nil expiresAt must not trigger refresh")
    }

    func testNeedsRefreshTrueWhenExpiredInPast() {
        let past = Date().addingTimeInterval(-300)
        let cred = ClaudeOAuthCredential(accessToken: "tok", expiresAt: past, source: "test")
        XCTAssertTrue(cred.needsRefresh)
    }

    func testNeedsRefreshTrueWithin120Seconds() {
        let soon = Date().addingTimeInterval(60)
        let cred = ClaudeOAuthCredential(accessToken: "tok", expiresAt: soon, source: "test")
        XCTAssertTrue(cred.needsRefresh, "tokens expiring in <120 s must trigger proactive refresh")
    }

    func testNeedsRefreshFalseWhenFarFuture() {
        let future = Date().addingTimeInterval(3600)
        let cred = ClaudeOAuthCredential(accessToken: "tok", expiresAt: future, source: "test")
        XCTAssertFalse(cred.needsRefresh)
    }

    // MARK: - nested claudeAiOauth key with ISO 8601

    func testParseJSONHandlesNestedKeyWithISO8601Expiry() {
        let json = """
        {
            "claudeAiOauth": {
                "accessToken": "nested_tok",
                "refreshToken": "rt",
                "expiresAt": "2026-08-19T15:00:00Z"
            }
        }
        """
        let cred = ClaudeLocalAuthReader.parseJSON(json, source: "test")
        XCTAssertEqual(cred?.accessToken, "nested_tok")
        XCTAssertEqual(cred?.refreshToken, "rt")
        XCTAssertNotNil(cred?.expiresAt, "Nested ISO 8601 expiresAt must parse")
    }
}
