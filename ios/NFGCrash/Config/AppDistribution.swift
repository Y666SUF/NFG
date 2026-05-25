import Foundation

/// Set `isAppStoreSubmission` to `true` before archiving for App Store / TestFlight upload.
enum AppDistribution {
    /// When true: hides dev test-store buttons; purchases use StoreKit only.
    static let isAppStoreSubmission = true

    /// **App Review only.** Set `true` while Apple is reviewing; set `false` before public release.
    /// Shows “App Review sign-in” on the link screen (no TikTok LIVE required). Server must set `MOBILE_APP_REVIEW_CODE`.
    static let allowAppReviewLogin = true

    static var usesAppleIAP: Bool { isAppStoreSubmission || !allowsDevTestStore }

    #if DEBUG
    static var allowsDevTestStore: Bool { !isAppStoreSubmission }
    #else
    static var allowsDevTestStore: Bool { false }
    #endif
}
