import Foundation
import Security

public enum KeychainError: Error, Sendable {
    case unexpectedStatus(OSStatus)
    case encodingFailed
}

public struct KeychainStore: Sendable {
    public static let appAccessGroup = "6998422DKP.com.jamesware.aimeter.app"

    public let service: String
    /// Data-protection items are granted by team ID, so Sparkle updates do not
    /// re-prompt. File-based items (Claude Code, etc.) stay on the login keychain.
    public let usesDataProtectionKeychain: Bool
    public let accessGroup: String?

    public init(
        service: String = "com.jamesware.aimeter.session",
        usesDataProtectionKeychain: Bool = true,
        accessGroup: String? = KeychainStore.appAccessGroup
    ) {
        self.service = service
        self.usesDataProtectionKeychain = usesDataProtectionKeychain
        self.accessGroup = accessGroup
    }

    public func save(token: String, account: String) throws {
        guard let data = token.data(using: .utf8) else { throw KeychainError.encodingFailed }
        var wroteDataProtection = false
        if usesDataProtectionKeychain {
            do {
                try add(data: data, account: account, dataProtection: true)
                wroteDataProtection = copy(account: account, dataProtection: true) == token
                if wroteDataProtection {
                    delete(account: account, dataProtection: false)
                }
            } catch let KeychainError.unexpectedStatus(status) where status == errSecMissingEntitlement {
                wroteDataProtection = false
            }
        }
        if !wroteDataProtection {
            try add(data: data, account: account, dataProtection: false)
        }
    }

    public func load(account: String) -> String? {
        if usesDataProtectionKeychain, let value = copy(account: account, dataProtection: true) {
            return value
        }
        guard let value = copy(account: account, dataProtection: false) else { return nil }
        if usesDataProtectionKeychain {
            try? add(data: Data(value.utf8), account: account, dataProtection: true)
        }
        return value
    }

    /// First password item for this service (Claude Code stores JSON under an opaque account).
    public func loadFirst() -> String? {
        if usesDataProtectionKeychain, let value = copyFirst(dataProtection: true) {
            return value
        }
        return copyFirst(dataProtection: false)
    }

    public func delete(account: String) {
        delete(account: account, dataProtection: true)
        delete(account: account, dataProtection: false)
    }

    private func add(data: Data, account: String, dataProtection: Bool) throws {
        delete(account: account, dataProtection: dataProtection)
        var query = baseQuery(account: account, dataProtection: dataProtection)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
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

    private func copyFirst(dataProtection: Bool) -> String? {
        var query = baseQuery(account: nil, dataProtection: dataProtection)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
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
