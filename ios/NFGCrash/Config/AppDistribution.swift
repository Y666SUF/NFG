import Foundation

/// Set `isAppStoreSubmission` to `true` before archiving for App Store / TestFlight upload.
enum AppDistribution {
    /// When true: hides dev test-store buttons; purchases use StoreKit only.
    static let isAppStoreSubmission = true

    static var usesAppleIAP: Bool { isAppStoreSubmission || !allowsDevTestStore }

    #if DEBUG
    static var allowsDevTestStore: Bool { !isAppStoreSubmission }
    #else
    static var allowsDevTestStore: Bool { false }
    #endif
}
