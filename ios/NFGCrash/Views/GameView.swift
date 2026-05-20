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

            ZStack {
                NFGTheme.background.ignoresSafeArea()
                backgroundGlow

                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        header
                        taxPotBanner
                        topProfilesSection
                        Text(sync.sublineText)
                            .font(.system(size: 11))
                            .foregroundStyle(NFGTheme.muted)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        CrashChartView(
                            history: sync.multiplierHistory,
                            phase: sync.gameState.phase,
                            multiplier: sync.gameState.multiplier
                        )
                        .frame(height: max(100, layoutHeight * 0.28))

                        entriesPanel
                            .frame(maxHeight: max(56, layoutHeight * 0.22))

                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissBetKeyboard()
                    }

                    betDock
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .background(
                            NFGTheme.background
                                .shadow(color: .black.opacity(0.35), radius: 8, y: -4)
                        )
                }
                .padding(.bottom, lift)
                .animation(.easeOut(duration: keyboard.animationDuration), value: lift)

                if let roundResult = sync.roundResultPopup {
                    RoundResultPopupView(result: roundResult) {
                        sync.dismissRoundResultPopup()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
            }
        }
    }

    private var backgroundGlow: some View {
        RadialGradient(
            colors: [Color(red: 76/255, green: 29/255, blue: 149/255).opacity(0.45), .clear],
            center: .top,
            startRadius: 0,
            endRadius: 400
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            NFGCrashBrandLogo(height: 52)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(phaseLabel.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(NFGTheme.muted)
                Text(String(format: "%.2f×", sync.gameState.multiplier))
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundStyle(multColor)
                    .shadow(color: NFGTheme.accent.opacity(0.35), radius: 8)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var phaseLabel: String {
        switch sync.gameState.phase {
        case .idle: return "Idle"
        case .betting: return "Betting"
        case .running: return "Flying"
        case .ended: return "Crashed"
        }
    }

    private var multColor: Color {
        sync.gameState.phase == .ended ? NFGTheme.danger : NFGTheme.accent
    }

    private var topProfilesSection: some View {
        VStack(spacing: 0) {
            TopProfilesStrip(rows: sync.topBalances, compact: true) {
                showLeaderboard = true
            }
            Button {
                showLeaderboard = true
            } label: {
                HStack {
                    Text("View full leaderboard")
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Text(playerCountLabel)
                        .font(.system(size: 10, design: .monospaced))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
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
        Text("Tax Pot: \(sync.taxPotAmount.formatted()) pts")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(NFGTheme.gold)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color(red: 30/255, green: 41/255, blue: 59/255).opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NFGTheme.gold.opacity(0.35)))
    }

    private var entriesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Entries")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
                Spacer()
                if PlayerSession.isLoggedIn {
                    Text("\(sync.wallet.balance > 0 ? sync.wallet.balance : sync.profile.balance) pts")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(NFGTheme.accent2)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    let bets = sync.gameState.openBets
                    let queued = sync.gameState.queuedBets
                    if bets.isEmpty && queued.isEmpty {
                        Text("No entries this round")
                            .font(.system(size: 12))
                            .foregroundStyle(NFGTheme.muted)
                    } else {
                        ForEach(bets) { bet in
                            betRow(bet, queued: false)
                        }
                        if !queued.isEmpty {
                            Text("Queued — next round")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(NFGTheme.muted)
                            ForEach(queued) { bet in
                                betRow(bet, queued: true)
                            }
                        }
                    }

                    if let msg = sync.lastActionMessage {
                        Text(msg)
                            .font(.system(size: 11))
                            .foregroundStyle(NFGTheme.gold)
                    }
                }
            }
        }
        .padding(10)
        .background(NFGTheme.panel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
    }

    private func betRow(_ bet: OpenBet, queued: Bool) -> some View {
        HStack {
            Text(bet.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NFGTheme.text)
            Spacer()
            Text("\(bet.amount) → \(String(format: "%.2f", bet.cashout))×")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(queued ? NFGTheme.muted : NFGTheme.accent)
        }
    }

    private func dismissBetKeyboard() {
        focusedBetField = nil
    }

    /// Lifts the whole game (including bet fields) above the keyboard; zero when keyboard is hidden.
    private func keyboardLiftAmount(safeAreaBottom: CGFloat) -> CGFloat {
        guard focusedBetField != nil, keyboard.height > 0 else { return 0 }
        return max(0, keyboard.height - safeAreaBottom)
    }

    private var betDock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("!100 or 30k", text: $betAmount)
                    .focused($focusedBetField, equals: .amount)
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        dismissBetKeyboard()
                    }
                    .padding(10)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(NFGTheme.text)

                TextField("×", text: $cashoutTarget)
                    .focused($focusedBetField, equals: .cashout)
                    .keyboardType(.decimalPad)
                    .frame(width: 56)
                    .padding(10)
                    .background(NFGTheme.panel2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(NFGTheme.text)
            }

            HStack(spacing: 8) {
                Button {
                    dismissBetKeyboard()
                    let co = Double(cashoutTarget.replacingOccurrences(of: ",", with: ".")) ?? 0
                    Task { await sync.placeBet(amountText: betAmount, cashout: co) }
                } label: {
                    Text("PLACE BET")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(NFGTheme.accent)
                .disabled(!PlayerSession.isLoggedIn)

                Button("!bal") {
                    dismissBetKeyboard()
                    Task { await sync.checkBalance() }
                }
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(NFGTheme.accent2)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(NFGTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(NFGTheme.border))
            }

            Button("All-in @ 2×  (!all 2)") {
                dismissBetKeyboard()
                Task { await sync.sendCommand("!all 2") }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(NFGTheme.muted)
        }
        .padding(10)
        .background(NFGTheme.panel2.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }
}
