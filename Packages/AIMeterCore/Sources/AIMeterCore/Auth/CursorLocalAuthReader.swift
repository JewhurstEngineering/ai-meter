import Foundation

#if os(macOS)
import Security
import SQLite3

public struct LocalCursorCredential: Sendable, Equatable {
    public enum Source: String, Sendable {
        case cursorIDE = "Cursor IDE"
        case cursorAgent = "Cursor Agent keychain"
    }

    public var token: String
    public var source: Source
    public var cachedEmail: String?

    public init(token: String, source: Source, cachedEmail: String? = nil) {
        self.token = token
        self.source = source
        self.cachedEmail = cachedEmail
    }
}

/// Reads Cursor session JWTs from the local machine.
///
/// Cursor Agent keychain (`cursor-access-token`) and the IDE `state.vscdb`
/// can belong to **different** accounts. Prefer the IDE token to match the
/// account currently signed into the Cursor app.
public enum CursorLocalAuthReader {
    public static var defaultDatabaseURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/state.vscdb")
    }

    /// Ordered candidates: IDE first, then Agent keychain (if different).
    public static func credentialCandidates(databaseURL: URL = defaultDatabaseURL) -> [LocalCursorCredential] {
        var results: [LocalCursorCredential] = []

        if let ide = readIDECredential(databaseURL: databaseURL) {
            results.append(ide)
        }
        if let agentToken = readCursorAgentKeychainToken() {
            let duplicate = results.contains { $0.token == agentToken }
            if !duplicate {
                results.append(LocalCursorCredential(token: agentToken, source: .cursorAgent))
            }
        }
        return results
    }

    public static func preferredCredential(databaseURL: URL = defaultDatabaseURL) -> LocalCursorCredential? {
        credentialCandidates(databaseURL: databaseURL).first
    }

    public static func readAccessToken(databaseURL: URL = defaultDatabaseURL) -> String? {
        readIDECredential(databaseURL: databaseURL)?.token
    }

    public static func readIDECredential(databaseURL: URL = defaultDatabaseURL) -> LocalCursorCredential? {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_close(db) }

        guard let token = readValue(db: db, key: "cursorAuth/accessToken") else { return nil }
        let email = readValue(db: db, key: "cursorAuth/cachedEmail")
        return LocalCursorCredential(token: token, source: .cursorIDE, cachedEmail: email)
    }

    public static func readCursorAgentKeychainToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "cursor-access-token",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func readValue(db: OpaquePointer?, key: String) -> String? {
        // Keys are fixed literals from our code; escape single quotes defensively.
        let escaped = key.replacingOccurrences(of: "'", with: "''")
        let sql = "SELECT value FROM ItemTable WHERE key = '\(escaped)' LIMIT 1;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0)
        else {
            return nil
        }
        return String(cString: cString)
    }
}
#endif
