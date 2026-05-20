import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: SyncClient
    @State private var showLeaderboard = false
    @State private var showWallet = false
    @State private var showAppChat = false

    var body: some View {
        NavigationStack {
            Group {
                if PlayerSession.isLoggedIn {
                    GameView(showLeaderboard: $showLeaderboard)
                } else {
                    LinkTikTokView()
                }
            }
            .toolbarBackground(NFGTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    TikTokLiveBadge(
                        status: sync.tiktokLive,
                        activeAppUsers: sync.displayedActiveAppUsers,
                        showInAppCount: sync.showActiveAppUserCount
                    )
                }
                if PlayerSession.isLoggedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            Button {
                                showWallet = true
                            } label: {
                                Image(systemName: "wallet.pass.fill")
                            }
                            .accessibilityLabel("My wallet")
                            Button {
                                showAppChat = true
                            } label: {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                            }
                            .accessibilityLabel("App chat")
                            Button {
                                showLeaderboard = true
                            } label: {
                                Image(systemName: "list.number")
                            }
                            .accessibilityLabel("Leaderboard")
                        }
                    }
                }
            }
            .sheet(isPresented: $showLeaderboard) {
                LeaderboardView()
                    .environmentObject(sync)
            }
            .sheet(isPresented: $showWallet) {
                WalletView()
                    .environmentObject(sync)
            }
            .sheet(isPresented: $showAppChat) {
                AppChatView()
                    .environmentObject(sync)
            }
            .onAppear {
                if sync.connectionStatus == "Offline" {
                    sync.connect()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await sync.sendPresenceHeartbeat()
                    await sync.refreshMobileStatus()
                }
            }
        }
    }
}
