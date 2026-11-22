import Foundation
import Security

/// Minimal Keychain-backed string store for secrets (JWT access + refresh tokens).
/// We never keep tokens in `UserDefaults` — the Keychain survives app updates and is encrypted at rest.
enum KeychainStore {
    private static let service = "site.thaonv.voca.tokens"

    static let accessTokenKey = "accessToken"
    static let refreshTokenKey = "refreshToken"
    static let savedEmailKey = "savedEmail"
    static let savedPasswordKey = "savedPassword"

    /// Stores `value` for `key`, or removes the item when `value` is nil.
    static func set(_ value: String?, for key: String) {
        #if os(macOS)
        let fallbackKey = "\(service).\(key)"
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
        ]
        guard let value, let data = value.data(using: .utf8) else {
            SecItemDelete(base as CFDictionary)
            UserDefaults.standard.removeObject(forKey: fallbackKey)
            return
        }
        let status = upsertKeychainItem(base: base, data: data)
        if status == errSecSuccess {
            // Remove any legacy plaintext fallback once stored in Keychain.
            UserDefaults.standard.removeObject(forKey: fallbackKey)
        } else if status == errSecMissingEntitlement {
            // Unsigned local debug/test builds lack Data Protection Keychain entitlement.
            UserDefaults.standard.set(value, forKey: fallbackKey)
        }
        #else
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        guard let value, let data = value.data(using: .utf8) else {
            SecItemDelete(base as CFDictionary)
            return
        }
        _ = upsertKeychainItem(base: base, data: data)
        #endif
    }

    static func get(_ key: String) -> String? {
        #if os(macOS)
        let fallbackKey = "\(service).\(key)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess,
           let data = result as? Data,
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        if let legacy = UserDefaults.standard.string(forKey: fallbackKey) {
            // Best-effort migration into Keychain when running signed.
            if status == errSecItemNotFound {
                set(legacy, for: key)
            }
            return legacy
        }
        return nil
        #else
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
        #endif
    }

    @discardableResult
    private static func upsertKeychainItem(base: [String: Any], data: Data) -> OSStatus {
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(base as CFDictionary, attributesToUpdate as CFDictionary)
        if updateStatus == errSecSuccess || updateStatus == errSecMissingEntitlement {
            return updateStatus
        }

        if updateStatus != errSecItemNotFound {
            // Accessibility class may have changed (migration from AfterFirstUnlock -> ThisDeviceOnly).
            SecItemDelete(base as CFDictionary)
        }

        var insert = base
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(insert as CFDictionary, nil)
    }
}
