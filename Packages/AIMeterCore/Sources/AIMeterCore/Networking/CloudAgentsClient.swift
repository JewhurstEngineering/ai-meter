import Foundation

public enum CloudAgentsError: Error, Sendable, Equatable {
    case unauthorized
    case httpStatus(Int)
    case decodingFailed
}

public struct CloudAPIKeyInfo: Sendable, Equatable {
    public var apiKeyName: String?
    public var userEmail: String?

    public init(apiKeyName: String? = nil, userEmail: String? = nil) {
        self.apiKeyName = apiKeyName
        self.userEmail = userEmail
    }
}

public struct CloudAgentSummary: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var status: String
    public var runStatus: String?
    public var updatedAt: Date?
    public var url: URL?

    public init(
        id: String,
        name: String,
        status: String,
        runStatus: String? = nil,
        updatedAt: Date? = nil,
        url: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.runStatus = runStatus
        self.updatedAt = updatedAt
        self.url = url
    }

    public var displayStatus: String {
        if let runStatus, !runStatus.isEmpty {
            return runStatus
        }
        return status
    }

    public var isRunning: Bool {
        displayStatus.uppercased() == "RUNNING"
    }
}

public actor CloudAgentsClient {
    public static let shared = CloudAgentsClient()

    private let session: URLSession
    private let baseURL = URL(string: "https://api.cursor.com")!

    public init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        self.session = session == .shared ? URLSession(configuration: config) : session
    }

    public func validate(apiKey: String) async throws -> CloudAPIKeyInfo {
        let me: MeResponse = try await get("/v1/me", apiKey: apiKey)
        return CloudAPIKeyInfo(apiKeyName: me.apiKeyName, userEmail: me.userEmail)
    }

    public func listAgents(apiKey: String, limit: Int = 20) async throws -> [CloudAgentSummary] {
        let response: AgentListResponse = try await get(
            "/v1/agents?limit=\(min(max(limit, 1), 100))&includeArchived=false",
            apiKey: apiKey
        )
        let items = (response.items ?? []).filter { ($0.status ?? "").uppercased() != "ARCHIVED" }

        var summaries: [CloudAgentSummary] = []
        summaries.reserveCapacity(items.count)
        for (index, item) in items.enumerated() {
            var runStatus: String?
            if index < 8, let agentID = item.id, let runID = item.latestRunId, !runID.isEmpty {
                if let run: RunResponse = try? await get("/v1/agents/\(agentID)/runs/\(runID)", apiKey: apiKey) {
                    runStatus = run.status
                }
            }
            if let summary = Self.summary(from: item, runStatus: runStatus) {
                summaries.append(summary)
            }
        }

        return summaries.sorted { lhs, rhs in
            if lhs.isRunning != rhs.isRunning { return lhs.isRunning && !rhs.isRunning }
            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }
    }

    private func get<T: Decodable>(_ path: String, apiKey: String) async throws -> T {
        var request = URLRequest(url: URL(string: path, relativeTo: baseURL)!.absoluteURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudAgentsError.httpStatus(-1) }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw CloudAgentsError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw CloudAgentsError.httpStatus(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CloudAgentsError.decodingFailed
        }
    }

    private static func summary(from item: ListItem, runStatus: String?) -> CloudAgentSummary? {
        guard let id = item.id else { return nil }
        let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return CloudAgentSummary(
            id: id,
            name: (name?.isEmpty == false) ? name! : "Untitled agent",
            status: item.status ?? "ACTIVE",
            runStatus: runStatus,
            updatedAt: UsageSnapshotMapper.parseDate(item.updatedAt ?? item.createdAt),
            url: item.url.flatMap(URL.init(string:)) ?? URL(string: "https://cursor.com/agents/\(id)")
        )
    }

    private struct MeResponse: Decodable {
        var apiKeyName: String?
        var userEmail: String?
    }

    private struct AgentListResponse: Decodable {
        var items: [ListItem]?
    }

    private struct ListItem: Decodable {
        var id: String?
        var name: String?
        var status: String?
        var url: String?
        var createdAt: String?
        var updatedAt: String?
        var latestRunId: String?
    }

    private struct RunResponse: Decodable {
        var id: String?
        var status: String?
    }
}
