import Foundation

/// Saved personal Cursor session (metadata only). Token lives in Keychain under `id.uuidString`.
public struct AccountConnection: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var email: String?
    public var label: String
    public var createdAt: Date

    public init(id: UUID = UUID(), email: String? = nil, label: String = "", createdAt: Date = .now) {
        self.id = id
        self.email = email
        self.label = label
        self.createdAt = createdAt
    }

    public var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let email {
            if let at = email.firstIndex(of: "@") {
                return String(email[..<at])
            }
            return email
        }
        return "Account"
    }

    /// Short prefix for a stacked menu bar item.
    public var menuBarLabel: String {
        let s = displayLabel
        if s.count <= 12 { return s }
        return String(s.prefix(11)) + "…"
    }

    public var keychainAccount: String { id.uuidString }
    public var cloudAPIKeychainAccount: String { "\(id.uuidString).cloudApiKey" }
}

public struct AccountRegistry: Codable, Sendable, Equatable {
    public var connections: [AccountConnection]
    public var activeAccountID: UUID?

    public static let empty = AccountRegistry(connections: [], activeAccountID: nil)

    public init(connections: [AccountConnection] = [], activeAccountID: UUID? = nil) {
        self.connections = connections
        self.activeAccountID = activeAccountID
        normalizeActive()
    }

    public mutating func normalizeActive() {
        if let activeAccountID, connections.contains(where: { $0.id == activeAccountID }) {
            return
        }
        self.activeAccountID = connections.first?.id
    }

    public func connection(id: UUID) -> AccountConnection? {
        connections.first { $0.id == id }
    }
}

public enum AccountRegistryStore {
    private static let key = "accountRegistry"

    public static func load(defaults: UserDefaults = .standard) -> AccountRegistry {
        guard let data = defaults.data(forKey: key),
              let registry = try? JSONDecoder().decode(AccountRegistry.self, from: data)
        else {
            return .empty
        }
        var copy = registry
        copy.normalizeActive()
        return copy
    }

    public static func save(_ registry: AccountRegistry, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(registry) {
            defaults.set(data, forKey: key)
        }
    }

    /// If the registry is empty and the legacy `"primary"` Keychain slot has a token, move it to a UUID connection.
    @discardableResult
    public static func migrateLegacyPrimaryIfNeeded(
        keychain: KeychainStore,
        defaults: UserDefaults = .standard
    ) -> AccountRegistry {
        var registry = load(defaults: defaults)
        guard registry.connections.isEmpty else { return registry }
        guard let token = keychain.load(account: SessionAccount.defaultAccount) else { return registry }

        let id = UUID()
        registry.connections = [AccountConnection(id: id, email: nil, label: "", createdAt: Date())]
        registry.activeAccountID = id
        do {
            try keychain.save(token: token, account: id.uuidString)
            keychain.delete(account: SessionAccount.defaultAccount)
            save(registry, defaults: defaults)
        } catch {
            return load(defaults: defaults)
        }
        return registry
    }

    /// Pure helper for tests — does not touch Keychain.
    public static func planLegacyMigration(
        existing: AccountRegistry,
        legacyTokenPresent: Bool
    ) -> AccountRegistry? {
        guard existing.connections.isEmpty, legacyTokenPresent else { return nil }
        let id = UUID()
        return AccountRegistry(
            connections: [AccountConnection(id: id, email: nil, label: "", createdAt: Date(timeIntervalSince1970: 0))],
            activeAccountID: id
        )
    }
}

public struct AccountRuntime: Equatable, Identifiable, Sendable {
    public var connection: AccountConnection
    public var snapshot: UsageSnapshot?
    public var lastError: String?
    public var isRefreshing: Bool
    public var isAuthenticated: Bool
    public var hasCloudAPIKey: Bool
    public var cloudAPIKeyName: String?
    public var cloudAPIKeyEmail: String?
    public var cloudAgents: [CloudAgentSummary]
    public var cloudAgentsError: String?

    public var id: UUID { connection.id }

    public init(
        connection: AccountConnection,
        snapshot: UsageSnapshot? = nil,
        lastError: String? = nil,
        isRefreshing: Bool = false,
        isAuthenticated: Bool = false,
        hasCloudAPIKey: Bool = false,
        cloudAPIKeyName: String? = nil,
        cloudAPIKeyEmail: String? = nil,
        cloudAgents: [CloudAgentSummary] = [],
        cloudAgentsError: String? = nil
    ) {
        self.connection = connection
        self.snapshot = snapshot
        self.lastError = lastError
        self.isRefreshing = isRefreshing
        self.isAuthenticated = isAuthenticated
        self.hasCloudAPIKey = hasCloudAPIKey
        self.cloudAPIKeyName = cloudAPIKeyName
        self.cloudAPIKeyEmail = cloudAPIKeyEmail
        self.cloudAgents = cloudAgents
        self.cloudAgentsError = cloudAgentsError
    }
}
