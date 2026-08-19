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

    func testMissingSessionCopyNamesPaths() {
        XCTAssertTrue(CodexLocalAuthReader.missingSessionMessage().contains("codex login"))
        XCTAssertTrue(ClaudeLocalAuthReader.missingSessionMessage().contains("claude"))
    }
}
