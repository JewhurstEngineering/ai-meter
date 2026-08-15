import Foundation

public struct CodexOAuthCredential: Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var accountID: String?
    public var email: String?
    public var source: String

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        accountID: String? = nil,
        email: String? = nil,
        source: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accountID = accountID
        self.email = email
        self.source = source
    }
}

public enum CodexLocalAuthReader {
    #if os(macOS)
    public static var authFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/auth.json")
    }
    #endif

    public static func preferredCredential() -> CodexOAuthCredential? {
        #if os(macOS)
        return fromAuthFile()
        #else
        return nil
        #endif
    }

    public static func fromAuthFile(url: URL? = nil) -> CodexOAuthCredential? {
        #if os(macOS)
        let fileURL = url ?? authFileURL
        #else
        guard let fileURL = url else { return nil }
        #endif
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return parse(data, source: "~/.codex/auth.json")
    }

    public static func parse(_ data: Data, source: String) -> CodexOAuthCredential? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let tokens = obj["tokens"] as? [String: Any] ?? obj
        let access = (tokens["access_token"] as? String) ?? (obj["access_token"] as? String)
        guard let access, !access.isEmpty else { return nil }
        let refresh = (tokens["refresh_token"] as? String) ?? (obj["refresh_token"] as? String)
        let account = (tokens["account_id"] as? String) ?? (obj["account_id"] as? String)
        let email = obj["email"] as? String
        return CodexOAuthCredential(
            accessToken: access,
            refreshToken: refresh,
            accountID: account,
            email: email,
            source: source
        )
    }

    public static func writeRefreshedTokens(accessToken: String, refreshToken: String?, accountID: String?) throws {
        #if os(macOS)
        let url = authFileURL
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            root = obj
        }
        var tokens = root["tokens"] as? [String: Any] ?? [:]
        tokens["access_token"] = accessToken
        if let refreshToken { tokens["refresh_token"] = refreshToken }
        if let accountID { tokens["account_id"] = accountID }
        root["tokens"] = tokens
        root["last_refresh"] = ISO8601DateFormatter().string(from: Date())
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
        #endif
    }
}
