import Foundation

public enum PersonalAPIError: Error, Sendable {
    case httpStatus(Int)
    case decodingFailed
    case unauthorized
}

public actor PersonalUsageClient {
    public static let shared = PersonalUsageClient()

    private let session: URLSession
    private let baseURL = URL(string: "https://cursor.com")!

    public init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
        ]
        self.session = session == .shared ? URLSession(configuration: config) : session
    }

    public func fetchSnapshot(sessionToken: String) async throws -> UsageSnapshot {
        let cookie = try SessionCookieBuilder.cookieValue(fromStoredToken: sessionToken)
        let me: AuthMeResponse = try await get("/api/auth/me", cookie: cookie)
        guard me.sub != nil || me.id != nil else { throw PersonalAPIError.unauthorized }

        async let summaryTask: UsageSummaryResponse = get("/api/usage-summary", cookie: cookie)
        async let stripeTask: AuthStripeResponse = get("/api/auth/stripe", cookie: cookie)
        let summary = try await summaryTask
        let stripe = try? await stripeTask

        var aggregated: AggregatedUsageResponse?
        if let userId = me.id,
           let start = summary.billingCycleStart,
           let end = summary.billingCycleEnd,
           let startMs = Self.epochMs(start),
           let endMs = Self.epochMs(end)
        {
            aggregated = try? await post(
                "/api/dashboard/get-aggregated-usage-events",
                cookie: cookie,
                body: [
                    "teamId": 0,
                    "startDate": String(startMs),
                    "endDate": String(endMs),
                    "userId": userId,
                ]
            )
        }

        return UsageSnapshotMapper.map(summary: summary, stripe: stripe, aggregated: aggregated)
    }

    public func validate(sessionToken: String) async throws -> AuthMeResponse {
        let cookie = try SessionCookieBuilder.cookieValue(fromStoredToken: sessionToken)
        return try await get("/api/auth/me", cookie: cookie)
    }

    // MARK: - HTTP

    private func get<T: Decodable>(_ path: String, cookie: String) async throws -> T {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!.absoluteURL)
        request.httpMethod = "GET"
        request.setValue("WorkosCursorSessionToken=\(cookie)", forHTTPHeaderField: "Cookie")
        return try await send(request)
    }

    private func post<T: Decodable>(_ path: String, cookie: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!.absoluteURL)
        request.httpMethod = "POST"
        request.setValue("WorkosCursorSessionToken=\(cookie)", forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://cursor.com", forHTTPHeaderField: "Origin")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PersonalAPIError.httpStatus(-1) }
        if http.statusCode == 401 || http.statusCode == 204 {
            throw PersonalAPIError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PersonalAPIError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PersonalAPIError.decodingFailed
        }
    }

    private static func epochMs(_ iso: String) -> Int64? {
        guard let date = UsageSnapshotMapper.parseDate(iso) else { return nil }
        return Int64(date.timeIntervalSince1970 * 1000)
    }
}
