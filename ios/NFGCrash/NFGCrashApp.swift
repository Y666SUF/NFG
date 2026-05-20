import SwiftUI

@main
struct NFGCrashApp: App {
    @StateObject private var sync = SyncClient()

    init() {
        PlayerSession.applyDefaultServerIfNeeded()
        AdMobAppStartup.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sync)
                .preferredColorScheme(.dark)
        }
    }
}
