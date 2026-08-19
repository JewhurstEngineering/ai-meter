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

public struct ClaudeCredentialLookup: Sendable {
    public var credential: ClaudeOAuthCredential?
    public var failureMessage: String?

    public init(credential: ClaudeOAuthCredential?, failureMessage: String?) {
        self.credential = credential
        self.failureMessage = failureMessage
    }
}

public enum ClaudeLocalAuthReader {
    public static let keychainService = "Claude Code-credentials"
    public static let loginInstructions = "Run `claude` in Terminal, enter `/login`, wait for “Login successful,” then Reconnect."

    public static func preferredCredential() -> ClaudeOAuthCredential? {
        credentialLookup().credential
    }

    public static func credentialLookup() -> ClaudeCredentialLookup {
        #if os(macOS)
        let keychain = keychainLookup()
        if let credential = keychain.credential {
            return ClaudeCredentialLookup(credential: credential, failureMessage: nil)
        }
        if let credential = fromCredentialsFile() {
            return ClaudeCredentialLookup(credential: credential, failureMessage: nil)
        }
        let fileExists = FileManager.default.fileExists(atPath: credentialsFileURL.path)
        if keychain.status == errSecAuthFailed
            || keychain.status == errSecInteractionNotAllowed
            || keychain.status == errSecUserCanceled
        {
            return ClaudeCredentialLookup(
                credential: nil,
                failureMessage: "AI Meter could not read “Claude Code-credentials” from Keychain (status \(keychain.status)). In Keychain Access, allow AI Meter to read that item, or run `claude`, enter `/login`, and try Reconnect again."
            )
        }
        if fileExists {
            return ClaudeCredentialLookup(
                credential: nil,
                failureMessage: "Found ~/.claude/.credentials.json but it has no usable access token. \(loginInstructions)"
            )
        }
        return ClaudeCredentialLookup(
            credential: nil,
            failureMessage: "No Claude Code session was found in Keychain or ~/.claude/.credentials.json. \(loginInstructions) A Keychain prompt appears only when an unread credential item exists."
        )
        #else
        return ClaudeCredentialLookup(
            credential: nil,
            failureMessage: "Claude Code sign-in is only available on the Mac app."
        )
        #endif
    }

    #if os(macOS)
    private static func keychainLookup() -> (credential: ClaudeOAuthCredential?, status: OSStatus) {
        let login = KeychainStore(
            service: keychainService,
            usesDataProtectionKeychain: false,
            accessGroup: nil,
            recoversFromDataProtectionKeychain: false
        )
        let lookup = login.loadFirstLookup()
        if let raw = lookup.value {
            let credential = parseJSON(raw, source: "Claude Code keychain")
                ?? raw.nonEmptyCredential(source: "Claude Code keychain")
            return (credential, lookup.status)
        }
        return (nil, lookup.status)
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
        credentialLookup().failureMessage ?? "No Claude Code session found."
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
        if let s = value as? String {
            if let n = Double(s) {
                return Date(timeIntervalSince1970: n > 10_000_000_000 ? n / 1000 : n)
            }
            // Newer Claude Code versions write ISO 8601 (e.g. "2026-08-19T15:00:00Z").
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: s) { return d }
            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: s)
        }
        return nil
    }
}

private extension String {
    func nonEmptyCredential(source: String) -> ClaudeOAuthCredential? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return ClaudeOAuthCredential(accessToken: value, source: source)
    }
}
