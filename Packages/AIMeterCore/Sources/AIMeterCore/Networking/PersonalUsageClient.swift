import Foundation

public enum PersonalAPIError: Error, Sendable, Equatable {
    case httpStatus(Int)
    case decodingFailed
    case unauthorized
    /// HTTP 204 — empty body, not a signed-out session.
    case emptyResponse

    public static func from(httpStatus code: Int) -> PersonalAPIError {
        switch code {
        case 401: return .unauthorized
        case 204: return .emptyResponse
        default: return .httpStatus(code)
        }
    }

    /// Soft failures: keep the previous snapshot and skip the orange banner.
    public var keepsLastNumbers: Bool {
        switch self {
        case .decodingFailed, .emptyResponse: return true
        case .httpStatus(429): return true
        case .httpStatus(let code) where (500...599).contains(code): return true
        default: return false
        }
    }
}

extension PersonalAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired — sign in again."
        case .decodingFailed:
            return "Cursor’s usage API changed. Last numbers are kept. Open the Cursor dashboard to check."
        case .emptyResponse:
            return "Cursor returned an empty usage response. Last numbers are kept."
        case .httpStatus(let code) where (500...599).contains(code):
            return "Cursor’s servers returned an error (\(code)). Try again in a few minutes."
        case .httpStatus(let code):
            return "Usage refresh failed (HTTP \(code))."
        }
    }
}

public actor PersonalUsageClient {
    public static let shared = PersonalUsageClient()

    private let session: URLSession
    private let baseURL = URL(string: "https://cursor.com")!
    private let historyStore: BillingCycleHistoryStore
    private let dailySpendStore: DailySpendHistoryStore

    public init(
        session: URLSession = .shared,
        historyStore: BillingCycleHistoryStore = BillingCycleHistoryStore(),
        dailySpendStore: DailySpendHistoryStore = DailySpendHistoryStore()
    ) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15",
        ]
        self.session = session == .shared ? URLSession(configuration: config) : session
        self.historyStore = historyStore
        self.dailySpendStore = dailySpendStore
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
        var dailySpend: [UsageSnapshot.DailySpend] = []
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
            dailySpend = await fillDailySpend(
                cookie: cookie,
                userId: userId,
                start: start,
                end: end
            )
        }

        let currentSpend: UsageSnapshot.BillingCycleSpend?
        if let start = UsageSnapshotMapper.parseDate(summary.billingCycleStart),
           let end = UsageSnapshotMapper.parseDate(summary.billingCycleEnd),
           let aggregated,
           let spend = BillingCycleHistory.spend(from: aggregated, start: start, end: end, isCurrent: true)
        {
            currentSpend = spend
        } else {
            currentSpend = nil
        }

        let history = BillingCycleHistory.mergedHistory(current: currentSpend, previous: previousCycles)
        return UsageSnapshotMapper.map(
            summary: summary,
            stripe: stripe,
            aggregated: aggregated,
            cycleHistory: history,
            dailySpend: dailySpend
        )
    }

    private func fillDailySpend(
        cookie: String,
        userId: Int,
        start: Date,
        end: Date
    ) async -> [UsageSnapshot.DailySpend] {
        let days = await DailySpendHistory.fill(
            cycleStart: start,
            cycleEnd: end,
            cached: dailySpendStore.load(userID: userId)
        ) { windowStart, windowEnd in
            do {
                let response = try await self.postAggregated(
                    cookie: cookie,
                    start: windowStart,
                    end: windowEnd,
                    userId: userId
                )
                return response.resolvedTotalCents
            } catch {
                return nil
            }
        }
        let todayStart = Calendar.current.startOfDay(for: Date())
        dailySpendStore.save(
            userID: userId,
            CachedDailySpend(
                cycleStart: start,
                days: days.filter { $0.day < todayStart }
            )
        )
        return days
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
        let classified = PersonalAPIError.from(httpStatus: http.statusCode)
        if classified == .unauthorized || classified == .emptyResponse {
            throw classified
        }
        guard (200..<300).contains(http.statusCode) else {
            throw classified
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PersonalAPIError.decodingFailed
        }
    }
}
