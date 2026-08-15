import Foundation

public enum ConnectorType: String, Codable, Sendable, CaseIterable {
    case personalSession
    case localCursorSQLite
    case teamAdminAPI // stub — foundation only
}

public enum PersonalPlanTier: String, Codable, Sendable, CaseIterable {
    case free
    case pro
    case proPlus = "pro_plus"
    case ultra
    case unknown

    public init(membershipType: String) {
        switch membershipType.lowercased() {
        case "free": self = .free
        case "pro": self = .pro
        case "pro_plus", "pro+", "proplus": self = .proPlus
        case "ultra": self = .ultra
        default: self = .unknown
        }
    }

    public var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .proPlus: return "Pro+"
        case .ultra: return "Ultra"
        case .unknown: return "Cursor"
        }
    }
}
