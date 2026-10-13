import Foundation
import os
import Security

public protocol CredentialStore: Sendable {
    func load() -> Credentials?
    func save(_ credentials: Credentials) throws
    func delete()
}

/// Stores the account in the login keychain as a single generic-password item.
public struct KeychainCredentialStore: CredentialStore {
    private let service: String

    public init(service: String = "com.ptournaris.Breeze") {
        self.service = service
    }

    public struct KeychainError: LocalizedError {
        public let status: OSStatus
        public var errorDescription: String? {
            SecCopyErrorMessageString(status, nil) as String? ?? "Keychain error \(status)"
        }
    }

    public func load() -> Credentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let item = result as? [String: Any],
              let email = item[kSecAttrAccount as String] as? String,
              let data = item[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            if status != errSecItemNotFound { Logger.keychain.error("Load failed: \(status)") }
            return nil
        }
        return Credentials(email: email, password: password)
    }

    public func save(_ credentials: Credentials) throws {
        delete()
        let item: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: credentials.email,
            kSecAttrLabel as String: "Breeze (TCL Home account)",
            kSecValueData as String: Data(credentials.password.utf8),
        ]
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
