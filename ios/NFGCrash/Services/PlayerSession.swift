import Foundation

enum PlayerSession {
    private static let usernameKey = "nfg_tiktok_username"
    private static let displayNameKey = "nfg_display_name"
    private static let serverKey = "nfg_server_base_url"
    private static let serverConfigVersionKey = "nfg_server_config_version"
    private static let currentServerConfigVersion = 7

    /// Fixed public server — users cannot change this in the app.
    static var serverBaseURL: String { GameServerConfig.serverURL }

    static func applyDefaultServerIfNeeded() {
        let version = UserDefaults.standard.integer(forKey: serverConfigVersionKey)
        if version < currentServerConfigVersion {
            UserDefaults.standard.removeObject(forKey: serverKey)
            UserDefaults.standard.set(currentServerConfigVersion, forKey: serverConfigVersionKey)
        }
    }

    static var tiktokUsername: String {
        get { UserDefaults.standard.string(forKey: usernameKey) ?? "" }
        set {
            let cleaned = newValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "@", with: "")
                .lowercased()
            UserDefaults.standard.set(cleaned, forKey: usernameKey)
        }
    }

    static var displayName: String {
        get {
            let stored = UserDefaults.standard.string(forKey: displayNameKey) ?? ""
            if !stored.isEmpty { return stored }
            return tiktokUsername
        }
        set { UserDefaults.standard.set(newValue, forKey: displayNameKey) }
    }

    static var isLoggedIn: Bool { AuthStore.isLinked }
}
