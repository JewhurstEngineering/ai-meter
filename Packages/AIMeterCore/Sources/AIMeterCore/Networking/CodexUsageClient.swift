import Foundation

public actor CodexUsageClient {
    public static let shared = CodexUsageClient()

    private let session: URLSession
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let tokenURL = URL(string: "https://auth.openai.com/oauth/token")!
    private let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"

    public init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        self.session = session == .shared ? URLSession(configuration: config) : session
    }

    public func fetchSnapshot(credential: CodexOAuthCredential) async throws -> UsageSnapshot {
        do {
            return try await fetch(credential: credential, attempt: 0)
        } catch ProviderUsageError.unauthorized {
            guard let refresh = credential.refreshToken else { throw ProviderUsageError.unauthorized }
            let refreshed = try await refreshTokens(refresh, accountID: credential.accountID)
            return try await fetch(credential: refreshed, attempt: 0)
        }
    }

    private func fetch(credential: CodexOAuthCredential, attempt: Int) async throws -> UsageSnapshot {
        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AIMeter", forHTTPHeaderField: "User-Agent")
        if let accountID = credential.accountID, !accountID.isEmpty {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProviderUsageError.emptyResponse }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ProviderUsageError.unauthorized
        }
        if http.statusCode == 429, attempt == 0 {
            try await Task.sleep(nanoseconds: 1_500_000_000)
            return try await fetch(credential: credential, attempt: 1)
        }
        guard (200...299).contains(http.statusCode) else {
            throw ProviderUsageError.from(httpStatus: http.statusCode)
        }
        guard !data.isEmpty else { throw ProviderUsageError.emptyResponse }
        return try CodexUsageMapper.map(data)
    }

    private func refreshTokens(_ refreshToken: String, accountID: String?) async throws -> CodexOAuthCredential {
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
        let newRefresh = (obj["refresh_token"] as? String) ?? refreshToken
        let cred = CodexOAuthCredential(
            accessToken: access,
            refreshToken: newRefresh,
            accountID: accountID,
            source: "oauth refresh"
        )
        try? CodexLocalAuthReader.writeRefreshedTokens(
            accessToken: access,
            refreshToken: newRefresh,
            accountID: accountID
        )
        return cred
    }
}
