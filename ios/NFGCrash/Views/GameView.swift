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
            let chartHeight = min(168, max(120, layoutHeight * 0.26))

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
                            openBets: sync.gameState.openBets,
                            queuedBets: sync.gameState.queuedBets,
                            entriesActionMessage: sync.lastActionMessage,
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
            Task {
                await sync.refreshProfile()
                await sync.refreshLeaderboard()
                await sync.refreshWallet(force: true)
            }
        }
    }

    private var topProfilesSection: some View {
        VStack(spacing: 6) {
            TopProfilesStrip(rows: sync.topBalances, compact: true) {
                showLeaderboard = true
            }
            RecentCrashesStrip(
                crashes: sync.gameState.recentCrashes,
                inline: false,
                showAllFive: true
            )
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
                if PlayerSession.isLoggedIn {
                    let balance = sync.wallet.balance > 0 ? sync.wallet.balance : sync.profile.balance
                    NFGChip(text: "\(balance.formatted()) pts", icon: "wallet.pass.fill", tint: NFGTheme.accent2)
            } else {
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
