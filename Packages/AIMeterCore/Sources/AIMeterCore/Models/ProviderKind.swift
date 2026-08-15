import Foundation

/// Which product a saved connection and snapshot belong to.
public enum ProviderKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case cursor
    case claude
    case codex

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cursor: return "Cursor"
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }

    public var systemImage: String {
        switch self {
        case .cursor: return "sparkles"
        case .claude: return "brain"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

public enum QuotaWindowKind: String, Codable, Sendable {
    case rolling
    case billingCycle
}

public enum QuotaWindowRole: String, Codable, Sendable {
    case session
    case weekly
    case cursorModels
    case otherModels
    case totalIncluded
    case extra
}

public struct QuotaWindow: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var title: String
    public var percentUsed: Double
    public var resetsAt: Date?
    public var kind: QuotaWindowKind
    public var role: QuotaWindowRole

    public init(
        id: String,
        title: String,
        percentUsed: Double,
        resetsAt: Date? = nil,
        kind: QuotaWindowKind,
        role: QuotaWindowRole
    ) {
        self.id = id
        self.title = title
        self.percentUsed = percentUsed
        self.resetsAt = resetsAt
        self.kind = kind
        self.role = role
    }

    public var warningChannel: UsageSnapshot.WarningChannel? {
        switch role {
        case .cursorModels: return .cursorModels
        case .otherModels: return .otherModels
        case .totalIncluded: return .totalIncluded
        case .session: return .session
        case .weekly: return .weekly
        case .extra: return nil
        }
    }
}

public struct SpendMeter: Codable, Sendable, Equatable {
    public var title: String
    public var usedCents: Int?
    public var limitCents: Int?
    public var remainingCents: Int?
    public var enabled: Bool
    public var unlimited: Bool

    public init(
        title: String,
        usedCents: Int? = nil,
        limitCents: Int? = nil,
        remainingCents: Int? = nil,
        enabled: Bool = true,
        unlimited: Bool = false
    ) {
        self.title = title
        self.usedCents = usedCents
        self.limitCents = limitCents
        self.remainingCents = remainingCents
        self.enabled = enabled
        self.unlimited = unlimited
    }

    public var percentUsed: Double? {
        if unlimited { return nil }
        guard let used = usedCents, let limit = limitCents, limit > 0 else { return nil }
        return min(100, Double(used) / Double(limit) * 100)
    }
}

public enum ProviderUsageError: Error, Sendable, Equatable {
    case unauthorized
    case decodingFailed
    case emptyResponse
    case missingCredentials
    case refreshFailed
    case httpStatus(Int)

    public static func from(httpStatus code: Int) -> ProviderUsageError {
        switch code {
        case 401, 403: return .unauthorized
        case 204: return .emptyResponse
        default: return .httpStatus(code)
        }
    }

    public var isUnauthorized: Bool {
        if case .unauthorized = self { return true }
        return false
    }
}

extension ProviderUsageError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired — sign in again."
        case .decodingFailed:
            return "Usage API changed. Last numbers are kept."
        case .emptyResponse:
            return "Empty usage response. Last numbers are kept."
        case .missingCredentials:
            return "No local session found."
        case .refreshFailed:
            return "Could not refresh the sign-in token."
        case .httpStatus(let code) where (500...599).contains(code):
            return "Servers returned an error (\(code)). Try again in a few minutes."
        case .httpStatus(let code):
            return "Usage refresh failed (HTTP \(code))."
        }
    }
}
