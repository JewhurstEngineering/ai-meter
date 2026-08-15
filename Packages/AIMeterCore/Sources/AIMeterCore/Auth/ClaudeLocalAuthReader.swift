import Foundation
#if os(macOS)
import Security
#endif

public struct ClaudeOAuthCredential: Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
    public var source: String

    public init(accessToken: String, refreshToken: String? = nil, expiresAt: Date? = nil, source: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.source = source
    }

    public var needsRefresh: Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSinceNow < 120
    }
}

public enum ClaudeLocalAuthReader {
    public static let keychainService = "Claude Code-credentials"

    public static func preferredCredential() -> ClaudeOAuthCredential? {
        #if os(macOS)
        if let cred = fromKeychain() { return cred }
        if let cred = fromCredentialsFile() { return cred }
        #endif
        return nil
    }

    #if os(macOS)
    private static func fromKeychain() -> ClaudeOAuthCredential? {
        guard let raw = KeychainStore(service: keychainService).loadFirst() else { return nil }
        return parseJSON(raw, source: "Claude Code keychain")
            ?? ClaudeOAuthCredential(accessToken: raw.trimmingCharacters(in: .whitespacesAndNewlines), source: "Claude Code keychain")
    }

    private static func fromCredentialsFile() -> ClaudeOAuthCredential? {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return parseJSON(text, source: "~/.claude/.credentials.json")
    }
    #endif

    public static func parseJSON(_ raw: String, source: String) -> ClaudeOAuthCredential? {
        guard let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let nested = obj["claudeAiOauth"] as? [String: Any]
        let access = string(obj["accessToken"] ?? obj["access_token"] ?? nested?["accessToken"] ?? nested?["access_token"])
        guard let access, !access.isEmpty else { return nil }
        let refresh = string(obj["refreshToken"] ?? obj["refresh_token"] ?? nested?["refreshToken"] ?? nested?["refresh_token"])
        let expires = date(obj["expiresAt"] ?? obj["expires_at"] ?? nested?["expiresAt"] ?? nested?["expires_at"])
        return ClaudeOAuthCredential(accessToken: access, refreshToken: refresh, expiresAt: expires, source: source)
    }

    private static func string(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        return nil
    }

    private static func date(_ value: Any?) -> Date? {
        if let n = value as? Double {
            return Date(timeIntervalSince1970: n > 10_000_000_000 ? n / 1000 : n)
        }
        if let n = value as? Int {
            let v = Double(n)
            return Date(timeIntervalSince1970: v > 10_000_000_000 ? v / 1000 : v)
        }
        if let s = value as? String, let n = Double(s) {
            return Date(timeIntervalSince1970: n > 10_000_000_000 ? n / 1000 : n)
        }
        return nil
    }
}
