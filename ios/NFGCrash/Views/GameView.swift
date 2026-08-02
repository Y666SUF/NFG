import SwiftUI

struct GameView: View {
    private enum BetField: Hashable {
        case amount
        case cashout
    }

    @EnvironmentObject private var sync: SyncClient
    @Binding var showLeaderboard: Bool
    @FocusState private var focusedBetField: BetField?
    @StateObject private var keyboard = KeyboardLiftObserver()
    @State private var betAmount = "100"
    @State private var cashoutTarget = "2.00"
    @State private var repeatLastBet = AppPreferences.repeatLastBetEnabled
    @State private var isCashingOut = false

    var body: some View {
        GeometryReader { geo in
            let lift = keyboardLiftAmount(safeAreaBottom: geo.safeAreaInsets.bottom)
            let layoutHeight = max(geo.size.height - lift, 320)
            let chartHeight = min(168, max(120, layoutHeight * 0.26))

            ZStack {
                NFGSceneBackground(phase: sync.gameState.phase, multiplier: sync.displayMultiplier)

                VStack(spacing: 0) {
                    VStack(spacing: NFGSpacing.sm) {
                        taxPotBanner
                        topProfilesSection
                        if !sync.sublineText.isEmpty {
                            Text(sync.sublineText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(NFGTheme.muted)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if sync.isOfflinePlayMode || sync.connectionStatus == "Offline" {
                            offlineSyncBanner
                        }

                        if let nearMiss = sync.nearMissMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "target")
                                    .font(.system(size: 10, weight: .bold))
                                Text(nearMiss)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                            }
                            .foregroundStyle(NFGTheme.gold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                                    .fill(NFGTheme.gold.opacity(0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                                    .stroke(NFGTheme.gold.opacity(0.35), lineWidth: 1)
                            )
                        }

                        CrashChartView(
                            history: sync.multiplierHistory,
                            phase: sync.gameState.phase,
                            multiplier: sync.displayMultiplier,
                            crashPoint: sync.gameState.crashPoint,
                            bettingEndsAt: sync.gameState.bettingEndsAt,
                            openBets: sync.gameState.openBets,
                            queuedBets: sync.gameState.queuedBets,
                            entriesActionMessage: sync.lastActionMessage,
                            recentCrashes: sync.gameState.recentCrashes,
                            onCrashAnimationFinished: {
                                sync.presentPendingRoundResultPopup()
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: chartHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, NFGSpacing.md)
                    .padding(.top, NFGSpacing.xs)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissBetKeyboard()
                    }

                    betDock
                        .padding(.horizontal, NFGSpacing.md)
                        .padding(.bottom, NFGSpacing.sm)
                        .background(
                            VStack(spacing: 0) {
                                LinearGradient(
                                    colors: [NFGTheme.background.opacity(0), NFGTheme.background],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: 24)
                                NFGTheme.background
                            }
                            .ignoresSafeArea(edges: .bottom)
                        )
                }
                .padding(.bottom, lift)
                .animation(.easeOut(duration: keyboard.animationDuration), value: lift)

                if let roundResult = sync.roundResultPopup {
                    RoundResultPopupView(result: roundResult) {
                        sync.dismissRoundResultPopup()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(10)
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: sync.roundResultPopup != nil)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissBetKeyboard()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            if sync.connectionStatus == "Offline" { sync.connect() }
            repeatLastBet = AppPreferences.repeatLastBetEnabled
            if let last = LastBetStore.load() {
                betAmount = last.amountText
                cashoutTarget = String(format: "%.2f", last.cashout)
            }
            Task {
                await sync.refreshProfile()
                await sync.refreshLeaderboard()
                await sync.refreshWallet(force: true)
            }
        }
    }

    private var topProfilesSection: some View {
        TopProfilesStrip(rows: sync.topBalances, compact: true) {
            showLeaderboard = true
        }
    }

    private var taxPotBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NFGTheme.gold)
            Text("Tax Pot")
                .font(NFGFont.eyebrow(10))
                .foregroundStyle(NFGTheme.gold.opacity(0.9))
            Text("\(sync.taxPotAmount.formatted()) pts")
                .font(NFGFont.numeric(12, weight: .heavy))
                .foregroundStyle(NFGTheme.gold)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            NFGTheme.gold.opacity(0.18),
                            NFGTheme.gold.opacity(0.04),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                .stroke(NFGTheme.gold.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Offline banner

    private var offlineSyncBanner: some View {
        let pendingBits: [String] = [
            sync.pendingArcadeSyncCount > 0
                ? "\(sync.pendingArcadeSyncPoints.formatted()) pts"
                : nil,
            sync.pendingInventorySyncCount > 0
                ? "\(sync.pendingInventorySyncCount) steal\(sync.pendingInventorySyncCount == 1 ? "" : "s")"
                : nil,
            sync.pendingOfflineCount > 0
                ? "\(sync.pendingOfflineCount) action\(sync.pendingOfflineCount == 1 ? "" : "s")"
                : nil,
        ].compactMap { $0 }

        return HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline — Arcade still works")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text(
                    pendingBits.isEmpty
                        ? "Crash bets pause until the server is back. Progress syncs automatically."
                        : "Pending sync: \(pendingBits.joined(separator: " · "))"
                )
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
            }
            Spacer(minLength: 0)
            Button("Retry") { sync.connect() }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(NFGTheme.accent2)
        }
        .foregroundStyle(NFGTheme.gold)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                .fill(NFGTheme.gold.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                .stroke(NFGTheme.gold.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Bet dock

    private func dismissBetKeyboard() {
        focusedBetField = nil
    }

    private func keyboardLiftAmount(safeAreaBottom: CGFloat) -> CGFloat {
        guard focusedBetField != nil, keyboard.height > 0 else { return 0 }
        return max(0, keyboard.height - safeAreaBottom)
    }

    private var displayBalance: Int {
        let base: Int = {
            if sync.liveBalance > 0 { return sync.liveBalance }
            if sync.wallet.balance > 0 { return sync.wallet.balance }
            return sync.profile.balance
        }()
        return max(0, base + max(0, sync.pendingArcadeSyncPoints))
    }

    private let quickStakeAmounts = [1000, 5000, 10000, 25000]
    private let quickCashoutTargets = [1.5, 2.0, 3.0, 5.0]

    private var betDock: some View {
        VStack(spacing: NFGSpacing.sm) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NFGTheme.accent2)
                Text("PLACE A BET")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(NFGTheme.muted)
                Spacer()
                if PlayerSession.isLoggedIn, sync.wallet.inventory.stealCharges > 0 {
                    Button {
                        showLeaderboard = true
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text("\(sync.wallet.inventory.stealCharges)")
                                .font(NFGFont.numeric(11, weight: .heavy))
                        }
                        .foregroundStyle(NFGTheme.gold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(NFGTheme.gold.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if PlayerSession.isLoggedIn {
                    HStack(spacing: 4) {
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(displayBalance.formatted()) pts")
                            .font(NFGFont.numeric(13, weight: .heavy))
                            .contentTransition(.numericText())
                    }
                    .foregroundStyle(NFGTheme.accent2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(NFGTheme.accent2.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(NFGTheme.accent2.opacity(0.35), lineWidth: 1))
                }
            }

            HStack(spacing: NFGSpacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(NFGTheme.muted)
                    TextField("!100 or 30k", text: $betAmount)
                        .focused($focusedBetField, equals: .amount)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { dismissBetKeyboard() }
                        .font(NFGFont.numeric(15, weight: .bold))
                        .foregroundStyle(NFGTheme.text)
                        .nfgInputBackground(focused: focusedBetField == .amount)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cash out")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(NFGTheme.muted)
                    HStack(spacing: 4) {
                        TextField("2.00", text: $cashoutTarget)
                            .focused($focusedBetField, equals: .cashout)
                            .keyboardType(.decimalPad)
                            .font(NFGFont.numeric(15, weight: .bold))
                            .foregroundStyle(NFGTheme.text)
                        Text("×")
                            .font(NFGFont.numeric(15, weight: .heavy))
                            .foregroundStyle(NFGTheme.accent)
                    }
                    .nfgInputBackground(focused: focusedBetField == .cashout)
                }
                .frame(width: 110)
            }

            quickStakeRow
            quickCashoutRow

            if let activeBet = sync.activeCrashBet, sync.gameState.phase == .running {
                activeBetCashOutSection(activeBet)
            }

            Toggle(isOn: $repeatLastBet) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .bold))
                    Text("Repeat last bet")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(NFGTheme.muted)
            }
            .toggleStyle(SwitchToggleStyle(tint: NFGTheme.accent))
            .disabled(!PlayerSession.isLoggedIn)
            .onChange(of: repeatLastBet) { _, enabled in
                AppPreferences.repeatLastBetEnabled = enabled
            }

            HStack(spacing: NFGSpacing.sm) {
                Button {
                    dismissBetKeyboard()
                    let co = Double(cashoutTarget.replacingOccurrences(of: ",", with: ".")) ?? 0
                    Task { await sync.placeBet(amountText: betAmount, cashout: co) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("PLACE BET")
                            .tracking(1.2)
                    }
                }
                .buttonStyle(NFGPrimaryButtonStyle(
                    isDisabled: !PlayerSession.isLoggedIn
                ))
                .disabled(!PlayerSession.isLoggedIn)

                Button {
                    dismissBetKeyboard()
                    Task { await sync.checkBalance() }
                } label: {
                    Text("!bal")
                }
                .buttonStyle(NFGSecondaryButtonStyle(tint: NFGTheme.accent2))
            }
        }
        .padding(NFGSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.lg, style: .continuous)
                .fill(NFGTheme.betDockBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [NFGTheme.accent.opacity(0.45), NFGTheme.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: NFGTheme.accent.opacity(0.14), radius: 16, y: -4)
    }

    private func activeBetCashOutSection(_ bet: OpenBet) -> some View {
        let mult = sync.displayMultiplier
        let payout = sync.estimatedManualCashoutPayout(for: bet)
        let canCashOut = sync.canManualCashout && !isCashingOut

        return VStack(spacing: NFGSpacing.sm) {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NFGTheme.accent2)
                Text("Live bet · \(bet.amount.formatted()) @ \(String(format: "%.2f", bet.cashout))×")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.2f", mult))
                    .font(NFGFont.numeric(28, weight: .heavy))
                    .foregroundStyle(NFGTheme.accent2)
                    .contentTransition(.numericText())
                Text("×")
                    .font(NFGFont.numeric(18, weight: .heavy))
                    .foregroundStyle(NFGTheme.accent2.opacity(0.85))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("You'd get")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.muted)
                    Text("\(payout.formatted()) pts")
                        .font(NFGFont.numeric(16, weight: .heavy))
                        .foregroundStyle(NFGTheme.gold)
                        .contentTransition(.numericText())
                }
            }

            Button {
                guard canCashOut else { return }
                dismissBetKeyboard()
                isCashingOut = true
                Task {
                    await sync.manualCashout()
                    isCashingOut = false
                }
            } label: {
                HStack(spacing: 8) {
                    if isCashingOut {
                        ProgressView()
                            .tint(.black.opacity(0.85))
                    } else {
                        Image(systemName: "banknote.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(isCashingOut ? "CASHING OUT…" : "CASH OUT NOW")
                        .tracking(1.3)
                }
            }
            .buttonStyle(NFGPrimaryButtonStyle(
                tintGradient: NFGTheme.goldGradient,
                glowColor: NFGTheme.gold,
                isDisabled: !canCashOut || !PlayerSession.isLoggedIn
            ))
            .disabled(!canCashOut || !PlayerSession.isLoggedIn)

            if mult < 1.05 {
                Text("Wait until 1.05× to cash out early")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
            } else if bet.cashout > mult {
                Text("Auto cashout at \(String(format: "%.2f", bet.cashout))× if you hold — or tap above to take profit now")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(NFGTheme.mutedSoft)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(NFGSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                .fill(NFGTheme.accent2.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                .stroke(NFGTheme.accent2.opacity(0.35), lineWidth: 1)
        )
    }

    private var quickStakeRow: some View {
        HStack(spacing: 6) {
            ForEach(quickStakeAmounts, id: \.self) { amount in
                betQuickChip(label: formatQuickStake(amount), enabled: PlayerSession.isLoggedIn) {
                    betAmount = "\(amount)"
                }
            }
            betQuickChip(label: "Max", enabled: PlayerSession.isLoggedIn && displayBalance > 0) {
                betAmount = "\(displayBalance)"
            }
        }
    }

    private var quickCashoutRow: some View {
        HStack(spacing: 6) {
            ForEach(quickCashoutTargets, id: \.self) { mult in
                betQuickChip(
                    label: String(format: "%.1f×", mult),
                    enabled: PlayerSession.isLoggedIn,
                    tint: NFGTheme.accent
                ) {
                    cashoutTarget = String(format: "%.2f", mult)
                }
            }
        }
    }

    private func betQuickChip(
        label: String,
        enabled: Bool,
        tint: Color = NFGTheme.muted,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(enabled ? tint : NFGTheme.muted.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(NFGTheme.panel2)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(NFGTheme.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func formatQuickStake(_ amount: Int) -> String {
        if amount >= 1000 { return "\(amount / 1000)k" }
        return "\(amount)"
    }
}
