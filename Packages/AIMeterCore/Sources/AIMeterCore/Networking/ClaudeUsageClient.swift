import Foundation

public actor ClaudeUsageClient {
    public static let shared = ClaudeUsageClient()

    private let session: URLSession
    private let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private var cachedUserAgent: String?

    public init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 25
        self.session = session == .shared ? URLSession(configuration: config) : session
    }

    public func fetchSnapshot(credential: ClaudeOAuthCredential) async throws -> UsageSnapshot {
        try await fetch(token: credential.accessToken, attempt: 0)
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
}
