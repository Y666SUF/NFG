import Foundation

enum AppPreferences {
    static let chatBannerNotificationsKey = "nfg.chatBannerNotificationsEnabled"
    static let soundEffectsEnabledKey = "nfg.arcadeSoundEffectsEnabled"

    /// In-app top banners for new app chat messages (not system push).
    static var chatBannerNotificationsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: chatBannerNotificationsKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: chatBannerNotificationsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: chatBannerNotificationsKey)
        }
    }

    /// Arcade mini-game sound effects (system sounds).
    static var soundEffectsEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: soundEffectsEnabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: soundEffectsEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: soundEffectsEnabledKey)
        }
    }
}
