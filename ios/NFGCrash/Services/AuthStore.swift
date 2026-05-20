import Foundation
import Security

enum AuthStore {
    private static let tokenKey = "nfg_session_token"
    private static let userKey = "nfg_verified_user"
    private static let displayNameKey = "nfg_verified_display_name"
    private static let deviceIdKey = "nfg_device_id"

    static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: deviceIdKey)
        return id
    }

    static var sessionToken: String? {
        get { readKeychain(tokenKey) }
        set {
            if let newValue, !newValue.isEmpty {
                writeKeychain(tokenKey, newValue)
            } else {
                deleteKeychain(tokenKey)
            }
        }
    }

    static var verifiedUserId: String {
        get { UserDefaults.standard.string(forKey: userKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userKey) }
    }

    static var verifiedDisplayName: String {
        get { UserDefaults.standard.string(forKey: displayNameKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: displayNameKey) }
    }

    static var isLinked: Bool {
        !(sessionToken ?? "").isEmpty && !verifiedUserId.isEmpty
    }

    static func saveSession(token: String, userId: String, displayName: String) {
        sessionToken = token
        verifiedUserId = userId
        verifiedDisplayName = displayName.isEmpty ? userId : displayName
        PlayerSession.tiktokUsername = userId
        PlayerSession.displayName = verifiedDisplayName
    }

    static func clearSession() {
        sessionToken = nil
        verifiedUserId = ""
        verifiedDisplayName = ""
    }

    private static func readKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }

    private static func writeKeychain(_ key: String, _ value: String) {
        deleteKeychain(key)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func deleteKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
