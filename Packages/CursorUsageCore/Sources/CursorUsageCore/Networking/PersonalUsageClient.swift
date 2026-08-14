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
    private let historyStore: BillingCycleHistoryStore

    public init(session: URLSession = .shared, historyStore: BillingCycleHistoryStore = BillingCycleHistoryStore()) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
        ]
        self.session = session == .shared ? URLSession(configuration: config) : session
        self.historyStore = historyStore
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
        var previousCycles: [UsageSnapshot.BillingCycleSpend] = []
        if let userId = me.id,
           let startISO = summary.billingCycleStart,
           let endISO = summary.billingCycleEnd,
           let start = UsageSnapshotMapper.parseDate(startISO),
           let end = UsageSnapshotMapper.parseDate(endISO)
        {
            aggregated = try? await postAggregated(cookie: cookie, start: start, end: end, userId: userId)
            previousCycles = await walkHistory(
                cookie: cookie,
                userId: userId,
                currentStart: start,
                currentEnd: end,
                cached: historyStore.load(userID: userId)
            )
        }

        let currentSpend: UsageSnapshot.BillingCycleSpend?
        if let start = UsageSnapshotMapper.parseDate(summary.billingCycleStart),
           let end = UsageSnapshotMapper.parseDate(summary.billingCycleEnd),
           let aggregated,
           let spend = BillingCycleHistory.spend(from: aggregated, start: start, end: end, isCurrent: true)
        {
            currentSpend = spend
        } else if let start = UsageSnapshotMapper.parseDate(summary.billingCycleStart),
                  let end = UsageSnapshotMapper.parseDate(summary.billingCycleEnd)
        {
            currentSpend = .init(
                start: start,
                end: end,
                totalCents: aggregated?.resolvedTotalCents ?? 0,
                modelCount: aggregated?.aggregations?.count ?? 0,
                isCurrent: true
            )
        } else {
            currentSpend = nil
        }

        let history = BillingCycleHistory.mergedHistory(current: currentSpend, previous: previousCycles)
        return UsageSnapshotMapper.map(
            summary: summary,
            stripe: stripe,
            aggregated: aggregated,
            cycleHistory: history
        )
    }

    private func walkHistory(
        cookie: String,
        userId: Int,
        currentStart: Date,
        currentEnd: Date,
        cached: CachedCycleHistory
    ) async -> [UsageSnapshot.BillingCycleSpend] {
        let result = await BillingCycleHistory.walkPrevious(
            currentStart: currentStart,
            currentEnd: currentEnd,
            cached: cached
        ) { start, end in
            do {
                let response = try await postAggregated(
                    cookie: cookie,
                    start: start,
                    end: end,
                    userId: userId
                )
                if let spend = BillingCycleHistory.spend(from: response, start: start, end: end) {
                    return .spend(spend)
                }
                return .empty
            } catch {
                return .failed
            }
        }
        historyStore.save(
            userID: userId,
            CachedCycleHistory(cycles: result.cycles, reachedEnd: result.reachedEnd)
        )
        return result.cycles
    }

    private func postAggregated(
        cookie: String,
        start: Date,
        end: Date,
        userId: Int
    ) async throws -> AggregatedUsageResponse {
        try await post(
            "/api/dashboard/get-aggregated-usage-events",
            cookie: cookie,
            body: [
                "teamId": 0,
                "startDate": BillingCycleHistory.aggregatedDateMillis(start),
                "endDate": BillingCycleHistory.aggregatedDateMillis(end),
                "userId": userId,
            ]
        )
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
}
