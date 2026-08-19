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
        let login = KeychainStore(
            service: keychainService,
            usesDataProtectionKeychain: false,
            accessGroup: nil
        )
        let dataProtection = KeychainStore(
            service: keychainService,
            usesDataProtectionKeychain: true,
            accessGroup: nil
        )
        if let raw = login.loadFirst() ?? dataProtection.loadFirst() {
            return parseJSON(raw, source: "Claude Code keychain")
                ?? ClaudeOAuthCredential(accessToken: raw.trimmingCharacters(in: .whitespacesAndNewlines), source: "Claude Code keychain")
        }
        return nil
    }

    private static var credentialsFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
    }

    private static func fromCredentialsFile() -> ClaudeOAuthCredential? {
        let url = credentialsFileURL
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return parseJSON(text, source: "~/.claude/.credentials.json")
    }
    #endif

    public static func missingSessionMessage() -> String {
        #if os(macOS)
        let fileExists = FileManager.default.fileExists(atPath: credentialsFileURL.path)
        if fileExists {
            return "Found ~/.claude/.credentials.json but it has no access token. Sign in with Claude Code (`claude` in Terminal), then Reconnect."
        }
        return "No Claude Code session found (no Keychain item “Claude Code-credentials”, and no ~/.claude/.credentials.json). Sign in with Claude Code (`claude` in Terminal), then Reconnect. A Keychain prompt only appears if that item already exists."
        #else
        return "Claude Code sign-in is only available on the Mac app."
        #endif
    }

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
