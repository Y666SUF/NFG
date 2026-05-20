import Foundation

/// NFG Crash production AdMob IDs (AdMob → Apps → NFG Crash).
enum AdMobConfig {
    static let applicationID = "ca-app-pub-6359780264957734~8558662810"

    /// Rewarded — NFG Crash Coins
    static let rewardedAdUnitID = "ca-app-pub-6359780264957734/1707833917"

    static let rewardPoints = 10_000

    /// Ignore server cooldown/daily caps in the app UI (server must use updated `mobile-rewarded-ad.js` for claims).
    static let rewardedAdsUnlimited = true
}
