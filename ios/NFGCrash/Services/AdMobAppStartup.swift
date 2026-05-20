import Foundation

#if canImport(GoogleMobileAds)
import GoogleMobileAds
import AppTrackingTransparency

enum AdMobAppStartup {
    static func configure() {
        MobileAds.shared.start()
        requestTrackingIfNeeded()
    }

    private static func requestTrackingIfNeeded() {
        guard #available(iOS 14, *) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}
#else
enum AdMobAppStartup {
    static func configure() {}
}
#endif
