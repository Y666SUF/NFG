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
            Group {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-ChartGalaxyPreview") {
                    ChartGalaxyPreviewHost()
                } else {
                    ContentView()
                        .environmentObject(sync)
                }
                #else
                ContentView()
                    .environmentObject(sync)
                #endif
            }
            .preferredColorScheme(.dark)
        }
    }
}
