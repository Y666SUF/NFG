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

    var body: some View {
        GeometryReader { geo in
            let lift = keyboardLiftAmount(safeAreaBottom: geo.safeAreaInsets.bottom)
            let layoutHeight = max(geo.size.height - lift, 320)
            let chartHeight = max(140, layoutHeight * 0.34)
            let entriesHeight = max(80, layoutHeight * 0.26)

            ZStack {
                NFGSceneBackground(phase: sync.gameState.phase, multiplier: sync.gameState.multiplier)

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

                        CrashChartView(
                            history: sync.multiplierHistory,
                            phase: sync.gameState.phase,
                            multiplier: sync.gameState.multiplier,
                            crashPoint: sync.gameState.crashPoint,
                            bettingEndsAt: sync.gameState.bettingEndsAt,
                            onCrashAnimationFinished: {
                                sync.presentPendingRoundResultPopup()
                            }
                        )
                        .frame(height: chartHeight)
                        .clipped()

                        entriesPanel
                            .frame(maxHeight: entriesHeight)

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
            Task {
                await sync.refreshProfile()
                await sync.refreshLeaderboard()
                await sync.refreshWallet(force: true)
            }
        }
    }

    private var topProfilesSection: some View {
        VStack(spacing: 4) {
            TopProfilesStrip(rows: sync.topBalances, compact: true) {
                showLeaderboard = true
            }
            Button {
                showLeaderboard = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("View full leaderboard")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Spacer()
                    Text(playerCountLabel)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(NFGTheme.muted)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(NFGTheme.accent)
                .padding(.top, 4)
            }
        }
    }

    private var playerCountLabel: String {
        let total = sync.leaderboardTotalCount
        let shown = sync.fullBalances.count
        if total > 0, total != shown {
            return "\(shown) of \(total) players"
        }
        if total > 0 { return "\(total) players" }
        return "\(shown) players"
    }

    private var taxPotBanner: some View {
        HStack(alignment: .center, spacing: 10) {
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
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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

            RecentCrashesStrip(crashes: sync.gameState.recentCrashes, inline: true, showAllFive: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Entries

    private var entriesPanel: some View {
        VStack(alignment: .leading, spacing: NFGSpacing.sm) {
            HStack(spacing: 8) {
                NFGSectionHeader(title: "Entries", icon: "person.3.fill")
                if PlayerSession.isLoggedIn {
                    let balance = sync.wallet.balance > 0 ? sync.wallet.balance : sync.profile.balance
                    NFGChip(text: "\(balance.formatted()) pts", icon: "wallet.pass.fill", tint: NFGTheme.accent2)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    let bets = sync.gameState.openBets
                    let queued = sync.gameState.queuedBets
                    if bets.isEmpty && queued.isEmpty {
                        emptyEntriesPlaceholder
                    } else {
                        ForEach(bets) { bet in
                            betRow(bet, queued: false)
                        }
                        if !queued.isEmpty {
                            Text("Queued — next round".uppercased())
                                .font(NFGFont.eyebrow(9))
                                .tracking(1.2)
                                .foregroundStyle(NFGTheme.muted)
                                .padding(.top, 4)
                            ForEach(queued) { bet in
                                betRow(bet, queued: true)
                            }
                        }
                    }

                    if let msg = sync.lastActionMessage {
                        Text(msg)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NFGTheme.gold)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .nfgCard(radius: NFGRadius.lg, padding: NFGSpacing.md)
    }

    private var emptyEntriesPlaceholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "rocket")
                .font(.system(size: 14))
                .foregroundStyle(NFGTheme.muted.opacity(0.7))
            Text("No entries this round")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
        }
        .padding(.vertical, 6)
    }

    private func betRow(_ bet: OpenBet, queued: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(queued ? NFGTheme.muted.opacity(0.5) : NFGTheme.accent.opacity(0.85))
                .frame(width: 6, height: 6)
            Text(bet.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NFGTheme.text)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text("\(bet.amount.formatted())")
                .font(NFGFont.numeric(11, weight: .semibold))
                .foregroundStyle(NFGTheme.muted)
            Image(systemName: "arrow.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NFGTheme.muted.opacity(0.6))
            Text(String(format: "%.2f×", bet.cashout))
                .font(NFGFont.numeric(12, weight: .heavy))
                .foregroundStyle(queued ? NFGTheme.muted : NFGTheme.accent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.sm)
                .fill(queued ? Color.clear : NFGTheme.accent.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.sm)
                .stroke(queued ? NFGTheme.border.opacity(0.4) : NFGTheme.accent.opacity(0.18), lineWidth: 0.8)
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
                if !PlayerSession.isLoggedIn {
                    Text("Link TikTok to bet")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NFGTheme.danger.opacity(0.85))
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

            Button {
                dismissBetKeyboard()
                Task { await sync.sendCommand("!all 2") }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                    Text("All-in @ 2× (!all 2)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(NFGTheme.gold.opacity(0.85))
            }
        }
        .padding(NFGSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.lg, style: .continuous)
                .fill(NFGTheme.betDockBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.lg, style: .continuous)
                .stroke(NFGTheme.accent.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: NFGTheme.accent.opacity(0.12), radius: 14, y: -2)
    }
}
