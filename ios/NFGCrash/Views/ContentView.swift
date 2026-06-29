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
                    } else if sync.isBootstrappingSession || sync.connectionStatus == "Connecting…" {
                        VStack(spacing: 16) {
                            ProgressView()
                                .tint(NFGTheme.accent2)
                            Text("Starting…")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(NFGTheme.muted)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 20) {
                            Text("Can't reach the game server")
                                .font(.headline)
                                .foregroundStyle(NFGTheme.text)
                            Button("Try again") { sync.connect() }
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                sync.connect()
            }
            .onChange(of: sync.connectionStatus) { _, status in
                guard PlayerSession.isLoggedIn, status == "Online" else { return }
                Task { await sync.refreshActiveAppUsers() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    _ = await AuthStore.refreshSessionFromServer()
                    await sync.refreshActiveAppUsers()
                    await sync.refreshMobileStatus()
                }
            }
        }
    }
}
