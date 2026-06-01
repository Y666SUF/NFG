import SwiftUI

@main
struct NFGLiveApp: App {
    @StateObject private var speech: SpeechManager
    @StateObject private var client: LiveCasterClient

    init() {
        let speechManager = SpeechManager()
        _speech = StateObject(wrappedValue: speechManager)
        _client = StateObject(wrappedValue: LiveCasterClient(speech: speechManager))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(client)
                .environmentObject(speech)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onAppear { client.start() }
        }
    }
}
