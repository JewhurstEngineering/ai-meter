import Foundation

public actor ClaudeUsageClient {
    public static let shared = ClaudeUsageClient()

    private let session: URLSession
    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let tokenURL = URL(string: "https://console.anthropic.com/v1/oauth/token")!
    private let clientID = "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    private var cachedUserAgent: String?

    public init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 25
        self.session = session == .shared ? URLSession(configuration: config) : session
    }

    public func fetchSnapshot(credential: ClaudeOAuthCredential) async throws -> UsageSnapshot {
        var token = credential.accessToken
        if credential.needsRefresh, let refresh = credential.refreshToken {
            token = try await refreshAccessToken(refresh)
        }
        do {
            return try await fetch(token: token, attempt: 0)
        } catch ProviderUsageError.unauthorized where credential.refreshToken != nil {
            let refreshed = try await refreshAccessToken(credential.refreshToken!)
            return try await fetch(token: refreshed, attempt: 0)
        }
    }

    private func fetch(token: String, attempt: Int) async throws -> UsageSnapshot {
        let agent = userAgent(reload: attempt > 0)
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(agent, forHTTPHeaderField: "User-Agent")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderUsageError.emptyResponse }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ProviderUsageError.unauthorized
        }
        if http.statusCode == 429, attempt == 0 {
            cachedUserAgent = nil
            let refreshed = userAgent(reload: true)
            if refreshed != agent {
                return try await fetch(token: token, attempt: 1)
            }
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await fetch(token: token, attempt: 1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderUsageError.from(httpStatus: http.statusCode)
        }
        guard !data.isEmpty else { throw ProviderUsageError.emptyResponse }
        return try ClaudeUsageMapper.map(data)
    }

    private func userAgent(reload: Bool) -> String {
        if !reload, let cachedUserAgent { return cachedUserAgent }
        let value = ClaudeCodeVersion.userAgent()
        cachedUserAgent = value
        return value
    }

    private func refreshAccessToken(_ refreshToken: String) async throws -> String {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": clientID,
        ])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ProviderUsageError.refreshFailed
        }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = obj["access_token"] as? String
        else {
            throw ProviderUsageError.refreshFailed
        }
        return access
    }
}
