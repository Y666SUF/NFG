import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: SyncClient
    @State private var showLeaderboard = false
    @State private var showWallet = false
    @State private var showAppChat = false
    @State private var showInAppUsers = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Group {
                    if PlayerSession.isLoggedIn {
                        GameView(showLeaderboard: $showLeaderboard)
                            .safeAreaInset(edge: .top, spacing: 0) {
                                VStack(spacing: 0) {
                                    GameNavigationToolbarRow(
                                        onWallet: { showWallet = true },
                                        onChat: { showAppChat = true },
                                        onLeaderboard: { showLeaderboard = true },
                                        onInAppList: { showInAppUsers = true }
                                    )
                                    GameTopPresenceBar(
                                        liveStatus: sync.tiktokLive,
                                        phase: sync.gameState.phase
                                    )
                                }
                                .background(NFGTheme.background.opacity(0.98))
                            }
                    } else {
                        LinkTikTokView()
                    }
                }

                if PlayerSession.isLoggedIn,
                   !sync.suppressChatBanners,
                   let banner = sync.activeChatBanner {
                    InAppChatBannerView(
                        notification: banner,
                        onDismiss: { sync.dismissChatBanner() },
                        onOpenChat: {
                            sync.dismissChatBanner()
                            showAppChat = true
                        }
                    )
                    .padding(.horizontal, NFGSpacing.md)
                    .padding(.top, NFGSpacing.xs)
                    .zIndex(50)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.38, dampingFraction: 0.86), value: sync.activeChatBanner?.id)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(NFGTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
            .sheet(isPresented: $showInAppUsers) {
                ActiveAppUsersListView()
                    .environmentObject(sync)
            }
            .onChange(of: showAppChat) { _, isOpen in
                sync.suppressChatBanners = isOpen
                if isOpen {
                    sync.dismissChatBanner()
                }
            }
            .onAppear {
                if sync.connectionStatus == "Offline" {
                    sync.connect()
                } else if PlayerSession.isLoggedIn {
                    Task { await sync.refreshActiveAppUsers() }
                }
            }
            .onChange(of: sync.connectionStatus) { _, status in
                guard PlayerSession.isLoggedIn, status == "Online" else { return }
                Task { await sync.refreshActiveAppUsers() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await sync.refreshActiveAppUsers()
                    await sync.refreshMobileStatus()
                }
            }
        }
    }
}
