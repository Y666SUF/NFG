import SwiftUI

struct BlocksGameScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sync: SyncClient
    @State private var api: GameAPI?
    @State private var busy = false
    @State private var sessionActive = false
    @State private var level = 1
    @State private var sessionPoints = 0
    @State private var offlinePending = 0
    @State private var linesTarget = 6
    @State private var rewardPreview = 5000
    @State private var message = ""
    @State private var loadError: String?
    @State private var showPlaySession = false
    @State private var leaderboardRefresh = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ArcadeSkillLobbyChrome(
                    gameId: "nfg_blocks",
                    title: "NFG BLOCKS",
                    subtitle: "Block puzzle · clear lines · earn pts each level",
                    titleColors: [ArcadeGameTheme.accent(for: "nfg_blocks"), .white],
                    stats: [
                        ArcadeSkillLobbyStat(text: "Lv \(level)", icon: "square.grid.3x3.fill", tint: NFGTheme.text),
                        ArcadeSkillLobbyStat(text: "Run \(sessionPoints.formatted())", icon: "star.fill", tint: NFGTheme.accent2),
                        ArcadeSkillLobbyStat(text: "+\(rewardPreview.formatted())/lv", icon: "gift.fill", tint: NFGTheme.gold),
                    ],
                    previewSystemImage: "square.grid.3x3.bottomleft.filled",
                    previewTitle: "Tap Play for a locked puzzle window",
                    previewSubtitle: "Drag blocks onto the 8×8 grid — no page scroll during play",
                    previewAccent: ArcadeGameTheme.accent(for: "nfg_blocks"),
                    playTint: ArcadeGameTheme.accent(for: "nfg_blocks"),
                    isLoading: busy,
                    offlinePendingPoints: offlinePending,
                    onPlay: { Task { await openPlaySession() } }
                )
                ArcadeInGameLeaderboard(gameId: "nfg_blocks", scoreSuffix: " Lv", fetchLimit: 10)
                    .id(leaderboardRefresh)
                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.muted)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 5 / 255, green: 8 / 255, blue: 16 / 255),
                    NFGTheme.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("NFG Blocks")
        .navigationBarTitleDisplayMode(.inline)
        .arcadeGameNavigationLock()
        .arcadeGameBackButton { dismiss() }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showPlaySession) {
            blocksPlaySession
                .interactiveDismissDisabled()
        }
        .task { await bootstrap() }
        .alert("Could not load", isPresented: .constant(loadError != nil)) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
    }

    private var blocksPlaySession: some View {
        ArcadePlaySessionChrome(
            gameId: "nfg_blocks",
            onClose: { closePlaySession() },
            headerTrailing: {
                HStack(spacing: 8) {
                    Text("Lv \(level)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ArcadeGameTheme.accent(for: "nfg_blocks"))
                    Text("\(sessionPoints.formatted()) pts")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                }
            },
            content: {
                BlocksGameView(
                    busy: busy,
                    serverLevel: level,
                    sessionPoints: sessionPoints,
                    offlinePendingPoints: offlinePending,
                    linesTarget: linesTarget,
                    rewardPreview: rewardPreview,
                    sessionActive: sessionActive,
                    embeddedInStage: true,
                    onStart: { await startGame() },
                    onLevelClear: { await levelClear() },
                    onGameOver: { await gameOver() }
                )
            },
            footer: {
                Text("Drag blocks — preview shows landing spot above your thumb")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        )
        .interactiveDismissDisabled()
    }

    @MainActor
    private func openPlaySession() async {
        await startGame()
        showPlaySession = true
    }

    private func closePlaySession() {
        if sessionActive {
            Task { await gameOver() }
        }
        showPlaySession = false
        leaderboardRefresh += 1
    }

    @MainActor
    private func bootstrap() async {
        busy = true
        defer { busy = false }
        refreshOfflinePending()
        do {
            let client = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
            api = client
            let synced = await ArcadeOfflinePointsQueue.flush(api: client, sync: sync)
            if synced > 0 {
                message = "Synced \(synced) offline reward\(synced == 1 ? "" : "s")."
            }
            refreshOfflinePending()
            let status = try await client.arcadePlay(gameId: "nfg_blocks", action: "status")
            applyStatus(status, action: "status")
        } catch {
            loadError = error.localizedDescription
            message = "Offline mode — points save locally and sync later."
        }
    }

    private func refreshOfflinePending() {
        offlinePending = ArcadeOfflinePointsQueue.pendingPoints(for: "nfg_blocks")
    }

    @MainActor
    private func applyStatus(_ result: ArcadePlayResponse, action: String) {
        ArcadePointsBridge.applyToGlobalWallet(result, sync: sync)
        if let active = result.sessionActive ?? result.runActive {
            sessionActive = active
        }
        if let lv = result.level { level = max(1, lv) }
        if action != "start" {
            if let pts = result.sessionPoints { sessionPoints = pts }
        }
        if let target = result.linesTarget { linesTarget = target }
        if let preview = result.levelRewardPreview { rewardPreview = preview }

        switch action {
        case "start":
            sessionActive = true
            sessionPoints = 0
            if let lv = result.level { level = lv }
            message = result.message ?? "Level \(level) — clear \(linesTarget) lines!"
        case "level_clear":
            sessionActive = true
            if let g = result.gained, g > 0 {
                message = "+\(g.formatted()) pts · Level \(level)"
            } else if let msg = result.message {
                message = msg
            }
        case "game_over":
            sessionActive = false
            if let msg = result.message {
                message = msg
            } else if let pts = result.sessionPoints {
                message = "Run over — \(pts.formatted()) session pts"
            }
            BlocksLocalStore.clear(user: ArcadeOfflinePointsQueue.userKey())
        default:
            if let msg = result.message, action == "status" { message = msg }
        }
        refreshOfflinePending()
    }

    @MainActor
    private func startGame() async {
        guard let api else {
            sessionActive = true
            sessionPoints = 0
            message = "Offline — points save locally."
            return
        }
        busy = true
        defer { busy = false }
        await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
        refreshOfflinePending()
        do {
            let res = try await api.arcadePlay(gameId: "nfg_blocks", action: "start")
            applyStatus(res, action: "start")
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func levelClear() async {
        let reward = rewardPreview
        guard let api else {
            ArcadeOfflinePointsQueue.enqueue(
                gameId: "nfg_blocks",
                action: "level_clear",
                estimatedPoints: reward
            )
            sessionActive = true
            level += 1
            linesTarget = BlocksEngine.linesTarget(for: level)
            rewardPreview = min(25000, 5000 + (level - 1) * 450)
            message = "+\(reward.formatted()) pts saved offline"
            refreshOfflinePending()
            return
        }
        busy = true
        defer { busy = false }
        await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
        refreshOfflinePending()
        do {
            let res = try await api.arcadePlay(gameId: "nfg_blocks", action: "level_clear")
            applyStatus(res, action: "level_clear")
        } catch {
            ArcadeOfflinePointsQueue.enqueue(
                gameId: "nfg_blocks",
                action: "level_clear",
                estimatedPoints: reward
            )
            sessionActive = true
            level += 1
            linesTarget = BlocksEngine.linesTarget(for: level)
            rewardPreview = min(25000, 5000 + (level - 1) * 450)
            message = "+\(reward.formatted()) pts saved offline"
            refreshOfflinePending()
        }
    }

    @MainActor
    private func gameOver() async {
        guard let api else {
            sessionActive = false
            BlocksLocalStore.clear(user: ArcadeOfflinePointsQueue.userKey())
            return
        }
        busy = true
        defer { busy = false }
        await ArcadeOfflinePointsQueue.flushBeforePlay(api: api, sync: sync)
        do {
            let res = try await api.arcadePlay(gameId: "nfg_blocks", action: "game_over")
            applyStatus(res, action: "game_over")
        } catch {
            message = error.localizedDescription
        }
    }
}
