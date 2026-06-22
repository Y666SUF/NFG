import Foundation
import Security

enum AuthStore {
    static let appGuestDisplayName = "App User"

    private static let tokenKey = "nfg_session_token"
    private static let userKey = "nfg_verified_user"
    private static let displayNameKey = "nfg_verified_display_name"
    private static let displayNameLockedKey = "nfg_display_name_locked"
    private static let linkedViaKey = "nfg_linked_via"
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

    static var linkedVia: String {
        get { UserDefaults.standard.string(forKey: linkedViaKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: linkedViaKey) }
    }

    /// When true, TikTok / server nickname updates must not replace the app-chosen display name.
    static var displayNameLocked: Bool {
        get { UserDefaults.standard.bool(forKey: displayNameLockedKey) }
        set { UserDefaults.standard.set(newValue, forKey: displayNameLockedKey) }
    }

    static var isLinked: Bool {
        !(sessionToken ?? "").isEmpty && !verifiedUserId.isEmpty
    }

    static var isAppGuest: Bool {
        linkedVia == "app_guest" || verifiedUserId.lowercased().hasPrefix("appuser_")
    }

    static var isTikTokLinked: Bool {
        linkedVia == "tiktok" || (isLinked && !isAppGuest)
    }

    /// Name shown in UI — "App User" until TikTok is linked.
    static var appFacingDisplayName: String {
        if isTikTokLinked {
            let n = verifiedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty { return n }
            let u = verifiedUserId.trimmingCharacters(in: .whitespacesAndNewlines)
            return u.isEmpty ? appGuestDisplayName : u
        }
        return appGuestDisplayName
    }

    static func saveGuestSession(token: String, userId: String, displayName: String = appGuestDisplayName) {
        sessionToken = token
        verifiedUserId = userId
        linkedVia = "app_guest"
        displayNameLocked = false
        PlayerSession.tiktokUsername = userId
        verifiedDisplayName = appGuestDisplayName
        PlayerSession.displayName = appGuestDisplayName
    }

    static func saveTikTokSession(token: String, userId: String, displayName: String) {
        sessionToken = token
        verifiedUserId = userId
        linkedVia = "tiktok"
        displayNameLocked = false
        PlayerSession.tiktokUsername = userId
        let cleaned = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = cleaned.isEmpty ? userId : cleaned
        verifiedDisplayName = name
        PlayerSession.displayName = name
    }

    static func saveSession(token: String, userId: String, displayName: String) {
        saveTikTokSession(token: token, userId: userId, displayName: displayName)
    }

    /// Keeps the last real TikTok nickname; ignores bare username when we already have a better name.
    static func applyCustomDisplayName(_ name: String) {
        guard isTikTokLinked else { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        verifiedDisplayName = cleaned
        PlayerSession.displayName = cleaned
        displayNameLocked = true
    }

    static func adoptDisplayNameFromServer(_ name: String, userId: String) {
        if isAppGuest { return }
        if displayNameLocked { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        let user = userId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
        let key = cleaned.lowercased().replacingOccurrences(of: "@", with: "")
        if !user.isEmpty && key == user {
            let existing = verifiedDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let existingKey = existing.lowercased().replacingOccurrences(of: "@", with: "")
            if !existing.isEmpty && existingKey != user { return }
        }
        verifiedDisplayName = cleaned
        PlayerSession.displayName = cleaned
    }

    static func clearSession() {
        sessionToken = nil
        verifiedUserId = ""
        verifiedDisplayName = ""
        linkedVia = ""
        displayNameLocked = false
        PlayerSession.clearLinkedProfile()
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
