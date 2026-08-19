import Foundation
import Security

public enum KeychainError: Error, Sendable {
    case unexpectedStatus(OSStatus)
    case encodingFailed
}

public struct KeychainLookup: Sendable {
    public var value: String?
    public var status: OSStatus

    public init(value: String?, status: OSStatus) {
        self.value = value
        self.status = status
    }
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            let detail = SecCopyErrorMessageString(status, nil) as String?
            return "Keychain failed (\(status)): \(detail ?? "Unknown error")"
        case .encodingFailed:
            return "The session could not be encoded for Keychain."
        }
    }
}

public struct KeychainStore: Sendable {
    public static let appAccessGroup = "6998422DKP.com.jamesware.aimeter.app"

    public let service: String
    /// Foreign CLI items stay in the login keychain. AI Meter also writes new
    /// items there; its stable designated requirement survives signed updates.
    public let usesDataProtectionKeychain: Bool
    public let accessGroup: String?
    public let recoversFromDataProtectionKeychain: Bool

    public init(
        service: String = "com.jamesware.aimeter.session",
        usesDataProtectionKeychain: Bool = false,
        accessGroup: String? = KeychainStore.appAccessGroup,
        recoversFromDataProtectionKeychain: Bool = true
    ) {
        self.service = service
        self.usesDataProtectionKeychain = usesDataProtectionKeychain
        self.accessGroup = accessGroup
        self.recoversFromDataProtectionKeychain = recoversFromDataProtectionKeychain
    }

    public func save(token: String, account: String) throws {
        guard let data = token.data(using: .utf8) else { throw KeychainError.encodingFailed }
        if usesDataProtectionKeychain {
            try upsert(data: data, account: account, dataProtection: true)
        } else {
            try upsert(data: data, account: account, dataProtection: false)
        }
    }

    public func load(account: String) -> String? {
        let primaryIsDataProtection = usesDataProtectionKeychain
        if let value = copy(account: account, dataProtection: primaryIsDataProtection) {
            return value
        }
        guard recoversFromDataProtectionKeychain else { return nil }
        let fallbackIsDataProtection = !primaryIsDataProtection
        guard let value = copy(account: account, dataProtection: fallbackIsDataProtection) else {
            return nil
        }
        // Copy forward without deleting the fallback. A failed migration must
        // never turn a readable session into a signed-out account.
        try? upsert(
            data: Data(value.utf8),
            account: account,
            dataProtection: primaryIsDataProtection
        )
        return value
    }

    /// First password item for this service (Claude Code stores JSON under an opaque account).
    public func loadFirst() -> String? {
        loadFirstLookup().value
    }

    public func loadFirstLookup() -> KeychainLookup {
        let primary = copyFirstLookup(dataProtection: usesDataProtectionKeychain)
        if primary.status == errSecSuccess || !recoversFromDataProtectionKeychain {
            return primary
        }
        let fallback = copyFirstLookup(dataProtection: !usesDataProtectionKeychain)
        return fallback.status == errSecSuccess ? fallback : primary
    }

    public func delete(account: String) {
        delete(account: account, dataProtection: usesDataProtectionKeychain)
        if recoversFromDataProtectionKeychain {
            delete(account: account, dataProtection: !usesDataProtectionKeychain)
        }
    }

    private func upsert(data: Data, account: String, dataProtection: Bool) throws {
        let query = baseQuery(account: account, dataProtection: dataProtection)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
        var add = query
        attributes.forEach { add[$0.key] = $0.value }
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    private func copy(account: String, dataProtection: Bool) -> String? {
        var query = baseQuery(account: account, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func copyFirstLookup(dataProtection: Bool) -> KeychainLookup {
        var query = baseQuery(account: nil, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return KeychainLookup(value: nil, status: status)
        }
        guard let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return KeychainLookup(value: nil, status: errSecDecode)
        }
        return KeychainLookup(value: value, status: errSecSuccess)
    }

    private func delete(account: String, dataProtection: Bool) {
        let query = baseQuery(account: account, dataProtection: dataProtection)
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(account: String?, dataProtection: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let account {
            query[kSecAttrAccount as String] = account
        }
        if dataProtection {
            query[kSecUseDataProtectionKeychain as String] = true
            if let accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }
        }
        return query
    }
}

public enum SessionAccount {
    public static let defaultAccount = "primary"
}
