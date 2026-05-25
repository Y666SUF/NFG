import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var sync: SyncClient
    @State private var showLeaderboard = false
    @State private var showWallet = false
    @State private var showAppChat = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Group {
                    if PlayerSession.isLoggedIn {
                        GameView(showLeaderboard: $showLeaderboard)
                            .safeAreaInset(edge: .top, spacing: 0) {
                                GameTopPresenceBar(
                                    liveStatus: sync.tiktokLive,
                                    activeAppUsers: sync.displayedActiveAppUsers,
                                    showInAppCount: sync.showActiveAppUserCount,
                                    activityAnnouncement: sync.presenceJoinAnnouncement,
                                    phase: sync.gameState.phase
                                )
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
            .toolbarBackground(NFGTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if PlayerSession.isLoggedIn {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 14) {
                            toolbarIconButton(systemName: "wallet.pass.fill", label: "Profile and wallet") {
                                showWallet = true
                            }
                            toolbarIconButton(systemName: "bubble.left.and.bubble.right.fill", label: "App chat") {
                                showAppChat = true
                            }
                            toolbarIconButton(systemName: "list.number", label: "Leaderboard") {
                                showLeaderboard = true
                            }
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
            .onChange(of: showAppChat) { _, isOpen in
                sync.suppressChatBanners = isOpen
                if isOpen {
                    sync.dismissChatBanner()
                }
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

    private func toolbarIconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .heavy))
                .foregroundStyle(NFGTheme.accent)
                .frame(width: 32, height: 32)
                .background(Circle().fill(NFGTheme.panel.opacity(0.9)))
                .overlay(Circle().stroke(NFGTheme.accent.opacity(0.25), lineWidth: 1))
        }
        .accessibilityLabel(label)
    }
}
