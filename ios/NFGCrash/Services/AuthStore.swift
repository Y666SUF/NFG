import Foundation
import Security

enum AuthStore {
    static let appGuestDisplayName = "App User"

    private static let keychainService = "com.yusufali.nfgcrash.auth"
    private static let tokenKey = "nfg_session_token"
    private static let userKey = "nfg_verified_user"
    private static let displayNameKey = "nfg_verified_display_name"
    private static let displayNameLockedKey = "nfg_display_name_locked"
    private static let linkedViaKey = "nfg_linked_via"
    private static let deviceIdKey = "nfg_device_id"
    /// Survives app updates; cleared only on explicit unlink in Settings.
    private static let tiktokAnchorKey = "nfg_tiktok_anchor_user"
    private static let didMigrateToKeychainKey = "nfg_auth_keychain_migrated_v1"

    static var deviceId: String {
        migrateLegacyStorageIfNeeded()
        if let existing = readKeychain(deviceIdKey), !existing.isEmpty {
            return existing
        }
        if let legacy = UserDefaults.standard.string(forKey: deviceIdKey), !legacy.isEmpty {
            writeKeychain(deviceIdKey, legacy)
            return legacy
        }
        let id = UUID().uuidString
        writeKeychain(deviceIdKey, id)
        UserDefaults.standard.set(id, forKey: deviceIdKey)
        return id
    }

    static var sessionToken: String? {
        migrateLegacyStorageIfNeeded()
        return readKeychain(tokenKey)
    }

    static var verifiedUserId: String {
        migrateLegacyStorageIfNeeded()
        if let kc = readKeychain(userKey), !kc.isEmpty { return kc }
        return UserDefaults.standard.string(forKey: userKey) ?? ""
    }

    static var verifiedDisplayName: String {
        migrateLegacyStorageIfNeeded()
        if let kc = readKeychain(displayNameKey), !kc.isEmpty { return kc }
        return UserDefaults.standard.string(forKey: displayNameKey) ?? ""
    }

    static var linkedVia: String {
        migrateLegacyStorageIfNeeded()
        if let kc = readKeychain(linkedViaKey), !kc.isEmpty { return kc }
        return UserDefaults.standard.string(forKey: linkedViaKey) ?? ""
    }

    /// Permanent TikTok username for this install — only cleared when user taps Unlink.
    static var tiktokAnchorUserId: String? {
        migrateLegacyStorageIfNeeded()
        guard let raw = readKeychain(tiktokAnchorKey)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
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
        let uid = verifiedUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if uid.hasPrefix("appuser_") { return true }
        if tiktokAnchorUserId != nil { return false }
        return linkedVia == "app_guest" && uid.isEmpty
    }

    static var isTikTokLinked: Bool {
        if linkedVia == "tiktok" { return true }
        if let anchor = tiktokAnchorUserId, !anchor.isEmpty { return true }
        guard isLinked, !isAppGuest else { return false }
        let uid = verifiedUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !uid.isEmpty && !uid.hasPrefix("appuser_") && uid != "apple_app_review"
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

    /// Call on launch before connect — restores TikTok identity from the permanent anchor.
    static func restoreAnchoredTikTokIdentityIfNeeded() {
        migrateLegacyStorageIfNeeded()
        guard let anchor = tiktokAnchorUserId else { return }
        let uid = anchor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty, !uid.lowercased().hasPrefix("appuser_") else { return }
        if verifiedUserId.isEmpty || verifiedUserId.lowercased() != uid.lowercased() {
            writeKeychain(userKey, uid)
            UserDefaults.standard.set(uid, forKey: userKey)
        }
        if linkedVia != "tiktok" {
            writeKeychain(linkedViaKey, "tiktok")
            UserDefaults.standard.set("tiktok", forKey: linkedViaKey)
        }
        PlayerSession.tiktokUsername = uid
        if verifiedDisplayName.isEmpty {
            let name = readKeychain(displayNameKey) ?? uid
            writeKeychain(displayNameKey, name)
            UserDefaults.standard.set(name, forKey: displayNameKey)
            PlayerSession.displayName = name
        }
    }

    static func saveGuestSession(token: String, userId: String, displayName: String = appGuestDisplayName) {
        writeKeychain(tokenKey, token)
        writeKeychain(userKey, userId)
        writeKeychain(linkedViaKey, "app_guest")
        writeKeychain(displayNameKey, appGuestDisplayName)
        UserDefaults.standard.set(userId, forKey: userKey)
        UserDefaults.standard.set(appGuestDisplayName, forKey: displayNameKey)
        UserDefaults.standard.set("app_guest", forKey: linkedViaKey)
        displayNameLocked = false
        PlayerSession.tiktokUsername = userId
        PlayerSession.displayName = appGuestDisplayName
    }

    static func saveTikTokSession(token: String, userId: String, displayName: String) {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = cleaned.isEmpty ? uid : cleaned
        writeKeychain(tokenKey, token)
        writeKeychain(userKey, uid)
        writeKeychain(linkedViaKey, "tiktok")
        writeKeychain(displayNameKey, name)
        writeKeychain(tiktokAnchorKey, uid)
        UserDefaults.standard.set(uid, forKey: userKey)
        UserDefaults.standard.set(name, forKey: displayNameKey)
        UserDefaults.standard.set("tiktok", forKey: linkedViaKey)
        displayNameLocked = false
        PlayerSession.tiktokUsername = uid
        PlayerSession.displayName = name
    }

    static func saveSession(token: String, userId: String, displayName: String) {
        saveTikTokSession(token: token, userId: userId, displayName: displayName)
    }

    /// Applies the server's canonical session for this device (guest, TikTok, or review).
    static func applyServerSession(
        token: String,
        userId: String,
        displayName: String,
        linkedVia serverLinkedVia: String?
    ) {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let via = (serverLinkedVia ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let anchor = tiktokAnchorUserId,
           !anchor.isEmpty,
           via == "app_guest" || uid.lowercased().hasPrefix("appuser_") {
            restoreAnchoredTikTokIdentityIfNeeded()
            if !token.isEmpty { writeKeychain(tokenKey, token) }
            return
        }

        switch via {
        case "tiktok":
            saveTikTokSession(token: token, userId: uid, displayName: displayName)
        case "app_guest":
            if tiktokAnchorUserId != nil {
                restoreAnchoredTikTokIdentityIfNeeded()
                if !token.isEmpty { writeKeychain(tokenKey, token) }
                return
            }
            saveGuestSession(token: token, userId: uid, displayName: displayName)
        case "app_review":
            writeKeychain(tokenKey, token)
            writeKeychain(userKey, uid)
            writeKeychain(linkedViaKey, "app_review")
            let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolved = name.isEmpty ? uid : name
            writeKeychain(displayNameKey, resolved)
            UserDefaults.standard.set(uid, forKey: userKey)
            UserDefaults.standard.set(resolved, forKey: displayNameKey)
            UserDefaults.standard.set("app_review", forKey: linkedViaKey)
            displayNameLocked = false
            PlayerSession.tiktokUsername = uid
            PlayerSession.displayName = resolved
        default:
            if uid.lowercased().hasPrefix("appuser_") {
                if tiktokAnchorUserId != nil {
                    restoreAnchoredTikTokIdentityIfNeeded()
                    if !token.isEmpty { writeKeychain(tokenKey, token) }
                    return
                }
                saveGuestSession(token: token, userId: uid, displayName: displayName)
            } else {
                saveTikTokSession(token: token, userId: uid, displayName: displayName)
            }
        }
    }

    /// Re-sync token with server. Never downgrades a linked TikTok user to App User.
    @MainActor
    static func refreshSessionFromServer() async -> Bool {
        restoreAnchoredTikTokIdentityIfNeeded()
        let claimUserId = tiktokAnchorUserId ?? (isTikTokLinked ? verifiedUserId : nil)
        do {
            let api = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
            let resp = try await api.bootstrapAppGuest(
                deviceId: deviceId,
                claimUserId: claimUserId
            )
            guard resp.ok == true,
                  let token = resp.token, !token.isEmpty,
                  let userId = resp.userId, !userId.isEmpty else {
                return claimUserId != nil && isTikTokLinked
            }

            if let anchor = claimUserId, !anchor.isEmpty {
                let serverUser = userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let serverVia = (resp.linkedVia ?? "").lowercased()
                let anchorKey = anchor.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if serverVia == "app_guest" || serverUser.hasPrefix("appuser_") {
                    restoreAnchoredTikTokIdentityIfNeeded()
                    return false
                }
                if serverUser != anchorKey {
                    restoreAnchoredTikTokIdentityIfNeeded()
                    return false
                }
            }

            applyServerSession(
                token: token,
                userId: userId,
                displayName: resp.displayName ?? appGuestDisplayName,
                linkedVia: resp.linkedVia
            )
            return true
        } catch {
            return claimUserId != nil && isTikTokLinked
        }
    }

    /// Keeps the last real TikTok nickname; ignores bare username when we already have a better name.
    static func applyCustomDisplayName(_ name: String) {
        guard isTikTokLinked else { return }
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        writeKeychain(displayNameKey, cleaned)
        UserDefaults.standard.set(cleaned, forKey: displayNameKey)
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
        writeKeychain(displayNameKey, cleaned)
        UserDefaults.standard.set(cleaned, forKey: displayNameKey)
        PlayerSession.displayName = cleaned
    }

    static func clearSession() {
        deleteKeychain(tokenKey)
        deleteKeychain(userKey)
        deleteKeychain(displayNameKey)
        deleteKeychain(linkedViaKey)
        deleteKeychain(tiktokAnchorKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        UserDefaults.standard.removeObject(forKey: displayNameKey)
        UserDefaults.standard.removeObject(forKey: linkedViaKey)
        displayNameLocked = false
        PlayerSession.clearLinkedProfile()
    }

    private static func migrateLegacyStorageIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: didMigrateToKeychainKey) else { return }
        if let token = readKeychain(tokenKey), token.isEmpty,
           let legacyToken = UserDefaults.standard.string(forKey: "nfg_session_token_legacy") {
            writeKeychain(tokenKey, legacyToken)
        }
        if let legacyUser = UserDefaults.standard.string(forKey: userKey), !legacyUser.isEmpty {
            writeKeychain(userKey, legacyUser)
        }
        if let legacyName = UserDefaults.standard.string(forKey: displayNameKey), !legacyName.isEmpty {
            writeKeychain(displayNameKey, legacyName)
        }
        if let legacyVia = UserDefaults.standard.string(forKey: linkedViaKey), !legacyVia.isEmpty {
            writeKeychain(linkedViaKey, legacyVia)
        }
        let storedVia = UserDefaults.standard.string(forKey: linkedViaKey) ?? ""
        let storedUser = UserDefaults.standard.string(forKey: userKey) ?? ""
        if storedVia == "tiktok" || isTikTokUserId(storedUser) {
            if !storedUser.isEmpty {
                writeKeychain(tiktokAnchorKey, storedUser)
            }
        }
        UserDefaults.standard.set(true, forKey: didMigrateToKeychainKey)
    }

    private static func isTikTokUserId(_ userId: String) -> Bool {
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !uid.isEmpty && !uid.hasPrefix("appuser_") && uid != "apple_app_review"
    }

    private static func isTikTokLinkedFromStoredProfile() -> Bool {
        let via = UserDefaults.standard.string(forKey: linkedViaKey) ?? ""
        if via == "tiktok" { return true }
        return isTikTokUserId(UserDefaults.standard.string(forKey: userKey) ?? "")
    }

    private static func readKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess,
           let data = item as? Data,
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        if status == errSecItemNotFound {
            return readLegacyKeychain(key)
        }
        return nil
    }

    private static func readLegacyKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let str = String(data: data, encoding: .utf8) else { return nil }
        writeKeychain(key, str)
        deleteLegacyKeychain(key)
        return str
    }

    private static func writeKeychain(_ key: String, _ value: String) {
        deleteKeychain(key)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func deleteKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        deleteLegacyKeychain(key)
    }

    private static func deleteLegacyKeychain(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
