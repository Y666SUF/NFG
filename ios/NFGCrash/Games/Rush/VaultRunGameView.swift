import SwiftUI

struct VaultRunGameView: View {
    let busy: Bool
    var sessionPoints: Int
    var offlinePendingPoints: Int = 0
    var rewardPreview: Int
    var sessionActive: Bool
    var bestDistance: Int
    var milestonesClaimed: Int
    var balance: Int
    var vaultShop: [VaultRunShipItem]
    var shipHullHex: String
    var shipCockpitHex: String
    var shipTrailHex: String
    var shipStyle: String
    var equippedShipId: String
    var isFullscreen: Bool = false
    var playSessionOnly: Bool = false
    var onCloseSession: (() -> Void)?
    var onStart: () async -> Void
    var onMilestone: (Int) async -> Bool
    var onGameOver: (Int) async -> Void
    var onBuyShip: (String) async -> VaultRunShopOutcome
    var onEquipShip: (String) async -> VaultRunShopOutcome

    @StateObject private var runHUD = VaultRunHUDState()
    @State private var runToken = 0
    @State private var localGameOver = false
    @State private var showRunSummary = false
    @State private var showShop = false
    @State private var lastRunPeak = 0
    @State private var lastRunPoints = 0

    private var pointsEarnedDisplay: Int {
        max(sessionPoints, runHUD.sessionPointsDisplay) + offlinePendingPoints
    }

    var body: some View {
        Group {
            if playSessionOnly {
                playSessionChrome
            } else if isFullscreen {
                runContent
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            } else {
                runStageWrapper
            }
        }
        .sheet(isPresented: $showRunSummary) {
            SnakeJumpRunSummarySheet(
                peakHeight: lastRunPeak,
                pointsEarned: lastRunPoints,
                personalBest: runHUD.displayBest,
                isNewBest: lastRunPeak >= runHUD.personalBest && lastRunPeak > 0,
                onPlayAgain: playSessionOnly ? { await restartRun() } : nil
            )
        }
    }

    private var playSessionChrome: some View {
        ArcadePlaySessionChrome(
            gameId: "nfg_vault_run",
            onClose: {
                if sessionActive && !localGameOver {
                    Task { await onGameOver(max(runHUD.runPeak, runHUD.distance)) }
                }
                onCloseSession?()
            },
            headerTrailing: {
                HStack(spacing: 8) {
                    Text("\(runHUD.distance)m")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(VaultRunTheme.accentOrange)
                        .monospacedDigit()
                    Text("Best \(runHUD.displayBest)m")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                    Text("\(pointsEarnedDisplay.formatted()) pts")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VaultRunTheme.accentJade)
                }
            },
            content: {
                immersiveCanvas
            },
            footer: {
                Text("Swipe lanes · jump ↑ · slide ↓ under table arches")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            },
            bottomBar: {
                HStack(spacing: 8) {
                    VaultRunShopButton { showShop = true }
                    Spacer()
                    if localGameOver {
                        ArcadePrimaryButton(
                            title: busy ? "…" : "Play Again",
                            icon: "arrow.clockwise",
                            tint: VaultRunTheme.accentGold,
                            disabled: busy
                        ) {
                            Task { await restartRun() }
                        }
                    } else if sessionActive {
                        ArcadePrimaryButton(
                            title: "End Run",
                            icon: "flag.checkered",
                            tint: NFGTheme.muted,
                            disabled: busy
                        ) {
                            Task {
                                await onGameOver(max(runHUD.runPeak, runHUD.distance))
                                localGameOver = true
                                lastRunPeak = max(runHUD.runPeak, runHUD.distance)
                                lastRunPoints = pointsEarnedDisplay
                                showRunSummary = true
                            }
                        }
                    }
                }
            }
        )
        .sheet(isPresented: $showShop) {
            VaultRunShopSheet(
                balance: balance,
                items: vaultShop.isEmpty ? VaultRunShopCatalog.defaultItems() : vaultShop,
                busy: busy,
                onBuy: onBuyShip,
                onEquip: onEquipShip
            )
        }
    }

    private var immersiveCanvas: some View {
        canvasStage
            .overlay(alignment: .topLeading) {
                VaultRunLiveDistanceBadge(
                    distance: runHUD.distance,
                    speedTier: runHUD.speedTier,
                    isActive: sessionActive && !localGameOver
                )
                .padding(10)
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if sessionActive, !localGameOver, runHUD.speedTier > 0 {
                    speedMeter
                        .padding(10)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .bottomLeading) {
                VaultRunCollapsibleObstacleLegend()
                    .padding(.leading, 10)
                    .padding(.bottom, 8)
            }
            .overlay {
                if localGameOver {
                    runBustOverlay
                }
            }
    }

    private var runBustOverlay: some View {
        ZStack {
            Color.black.opacity(0.62)
            VStack(spacing: 14) {
                Text("BUST!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(VaultRunTheme.accentGold)
                Text("\(lastRunPeak.formatted())m · +\(lastRunPoints.formatted()) pts")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                ArcadePrimaryButton(
                    title: busy ? "…" : "Play Again",
                    icon: "arrow.clockwise",
                    tint: VaultRunTheme.accentOrange,
                    disabled: busy
                ) {
                    Task { await restartRun() }
                }
                .padding(.horizontal, 24)
            }
            .padding(20)
        }
        .allowsHitTesting(true)
    }

    @MainActor
    private func restartRun() async {
        showRunSummary = false
        await onStart()
        runToken += 1
        localGameOver = false
        lastRunPoints = 0
        runHUD.sessionPointsDisplay = 0
    }

    private var runStageWrapper: some View {
        VStack(spacing: 16) {
            vaultRunHero
            runContent
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VaultRunTheme.panelStone, Color(red: 0.08, green: 0.06, blue: 0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    VaultRunTheme.accentGold.opacity(0.55),
                                    VaultRunTheme.accentOrange.opacity(0.35),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(color: VaultRunTheme.accentGold.opacity(0.15), radius: 14, y: 6)
    }

    private var vaultRunHero: some View {
        VStack(spacing: 8) {
            ArcadeSkillGameIcon(gameId: "nfg_vault_run", size: 52)
            Text("NFG RUSH")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [VaultRunTheme.accentGold, .white],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("3-lane casino run · dodge busts · jackpot every 400m+")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(NFGTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.04, green: 0.1, blue: 0.07), Color(red: 0.06, green: 0.05, blue: 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private var runContent: some View {
        VStack(spacing: isFullscreen ? 8 : 10) {
            if !isFullscreen && !playSessionOnly {
                ArcadeHowToPlayCard(gameId: "nfg_vault_run")
                VaultRunObstacleLegend()
            }

            if !playSessionOnly {
                statsRow
            }

            if rewardPreview > 0, !isFullscreen, !playSessionOnly {
                VaultRunMilestoneBanner(nextDistance: nextMilestoneDistance, reward: nextMilestoneReward)
            }

            if playSessionOnly {
                immersiveCanvas
            } else {
                canvasStage
                    .overlay(alignment: .topLeading) {
                        if isFullscreen {
                            VaultRunLiveDistanceBadge(
                                distance: runHUD.distance,
                                speedTier: runHUD.speedTier,
                                isActive: sessionActive && !localGameOver
                            )
                            .padding(10)
                            .allowsHitTesting(false)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        VStack(alignment: .trailing, spacing: 6) {
                            VaultRunShopButton { showShop = true }
                            if isFullscreen, sessionActive, !localGameOver, runHUD.speedTier > 0 {
                                speedMeter
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(10)
                    }
                    .overlay(alignment: .bottomLeading) {
                        if isFullscreen {
                            VaultRunCollapsibleObstacleLegend()
                                .padding(.leading, 10)
                                .padding(.bottom, 36)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if isFullscreen, sessionActive, !localGameOver {
                            vaultRunControlHint
                                .padding(.bottom, 10)
                                .allowsHitTesting(false)
                        }
                    }

                sessionButtons
            }
        }
        .sheet(isPresented: $showShop) {
            VaultRunShopSheet(
                balance: balance,
                items: vaultShop.isEmpty ? VaultRunShopCatalog.defaultItems() : vaultShop,
                busy: busy,
                onBuy: onBuyShip,
                onEquip: onEquipShip
            )
        }
    }

    private var canvasStage: some View {
        Group {
            if isFullscreen || playSessionOnly {
                ArcadeSkillStageFrame(gameId: "nfg_vault_run") {
                    runSceneHost
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, playSessionOnly ? 0 : 8)
            } else {
                VaultRunCanvasFrame {
                    runSceneHost
                        .frame(height: 340)
                }
            }
        }
    }

    private var runSceneHost: some View {
        VaultRunSceneHost(
            sessionActive: sessionActive,
            milestonesClaimed: milestonesClaimed,
            rewardPreview: rewardPreview,
            bestDistance: bestDistance,
            resetToken: runToken,
            shipHullHex: shipHullHex,
            shipCockpitHex: shipCockpitHex,
            shipTrailHex: shipTrailHex,
            shipStyle: shipStyle,
            equippedShipId: equippedShipId,
            hud: runHUD,
            onMilestone: onMilestone,
            onGameOver: onGameOver,
            onGameOverLocal: {
                localGameOver = true
                lastRunPeak = max(runHUD.runPeak, runHUD.distance)
                lastRunPoints = pointsEarnedDisplay
                showRunSummary = true
            }
        )
    }

    private var speedMeter: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(6, runHUD.speedTier + 1), id: \.self) { i in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(i <= runHUD.speedTier ? VaultRunTheme.accentOrange : Color.white.opacity(0.15))
                    .frame(width: 8, height: 10 + CGFloat(i) * 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(0.45))
        .clipShape(Capsule())
    }

    private var vaultRunControlHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.draw.fill")
            Text("Swipe lanes · jump ↑ · slide ↓ under table arches")
        }
        .font(.system(size: 10, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.78))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
    }

    private var nextMilestoneDistance: Int {
        VaultRunEngine.milestoneDistance(forTier: milestonesClaimed + 1)
    }

    private var nextMilestoneReward: Int {
        max(rewardPreview, VaultRunEngine.milestoneReward(forTier: milestonesClaimed + 1))
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            VaultRunStatChip(label: "Distance", value: "\(runHUD.distance)m", accent: VaultRunTheme.accentOrange, icon: "figure.run")
            VaultRunStatChip(label: "Your best", value: "\(runHUD.displayBest)m", accent: VaultRunTheme.accentGold, icon: "trophy.fill")
            VaultRunStatChip(label: "Pts earned", value: pointsEarnedDisplay.formatted(), accent: VaultRunTheme.accentJade, icon: "star.fill")
        }
    }

    private var sessionButtons: some View {
        HStack(spacing: 8) {
            if !sessionActive || localGameOver {
                ArcadePrimaryButton(
                    title: busy ? "…" : "New Run",
                    icon: "play.fill",
                    tint: VaultRunTheme.accentOrange,
                    disabled: busy
                ) {
                    Task { await restartRun() }
                }
            } else {
                ArcadePrimaryButton(
                    title: "End Run",
                    icon: "flag.checkered",
                    tint: NFGTheme.muted,
                    disabled: busy
                ) {
                    Task { await onGameOver(max(runHUD.runPeak, runHUD.distance)) }
                }
            }
        }
    }
}
