import SwiftUI

struct RoundResultPopupView: View {
    let result: RoundResultSummary
    let onDismiss: () -> Void

    @State private var heroScale: CGFloat = 0.88
    @State private var heroOpacity: Double = 0

    private var personal: RoundOutcome? {
        result.personalOutcome(for: AuthStore.verifiedUserId)
    }

    private var personalWin: Bool { personal?.isWin == true }
    private var personalLoss: Bool { personal != nil && personal?.isWin != true }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                personalHero
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: NFGSpacing.lg) {
                        if !result.wins.isEmpty {
                            outcomeSection(
                                title: "Winners",
                                icon: "checkmark.seal.fill",
                                color: NFGTheme.accent2,
                                rows: result.wins
                            )
                        }
                        if !result.losses.isEmpty {
                            outcomeSection(
                                title: "Crashed out",
                                icon: "xmark.octagon.fill",
                                color: NFGTheme.danger,
                                rows: result.losses
                            )
                        }
                    }
                    .padding(.horizontal, NFGSpacing.lg)
                    .padding(.vertical, NFGSpacing.md)
                }
                .frame(maxHeight: 320)

                Button(action: onDismiss) {
                    Text("CONTINUE")
                        .tracking(1.4)
                }
                .buttonStyle(NFGPrimaryButtonStyle())
                .padding(NFGSpacing.md)
            }
            .background(
                RoundedRectangle(cornerRadius: NFGRadius.xl, style: .continuous)
                    .fill(NFGTheme.panelGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NFGRadius.xl, style: .continuous)
                    .strokeBorder(NFGTheme.hairlineBorder, lineWidth: 1)
            )
            .padding(.horizontal, NFGSpacing.xl)
            .shadow(color: .black.opacity(0.55), radius: 30, y: 12)
            .shadow(color: accentGlow.opacity(0.2), radius: 24)
            .scaleEffect(heroScale)
            .opacity(heroOpacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                heroScale = 1
                heroOpacity = 1
            }
            if personalWin {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } else if personalLoss {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private var accentGlow: Color {
        if personalWin { return NFGTheme.accent2 }
        if personalLoss { return NFGTheme.danger }
        return NFGTheme.danger
    }

    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.78)
                .ignoresSafeArea()
            RadialGradient(
                colors: [accentGlow.opacity(0.28), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()
        }
        .onTapGesture { onDismiss() }
    }

    @ViewBuilder
    private var personalHero: some View {
        if let personal {
            VStack(spacing: 8) {
                Image(systemName: personalWin ? "checkmark.seal.fill" : "xmark.octagon.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(personalWin ? NFGTheme.accent2 : NFGTheme.danger)
                    .symbolEffect(.bounce, value: heroOpacity)

                if personalWin, let payout = personal.payout ?? personal.grossPayout {
                    Text("You cashed out!")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.muted)
                    Text("+\(formatPoints(payout)) pts")
                        .font(NFGFont.numeric(32, weight: .black))
                        .foregroundStyle(NFGTheme.accent2)
                        .contentTransition(.numericText())
                    if let bet = personal.bet, let target = personal.cashout {
                        Text("Bet \(formatPoints(bet)) @ \(String(format: "%.2f", target))×")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(NFGTheme.muted)
                    }
                } else {
                    Text("You busted")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(NFGTheme.danger)
                    if let bet = personal.bet {
                        Text("Lost \(formatPoints(bet)) pts")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(NFGTheme.muted)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, NFGSpacing.md)
            .background(
                LinearGradient(
                    colors: [
                        personalWin ? NFGTheme.accent2.opacity(0.12) : NFGTheme.danger.opacity(0.12),
                        NFGTheme.panel2.opacity(0.4),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }

    private var header: some View {
        VStack(spacing: NFGSpacing.sm) {
            HStack(spacing: 6) {
                Text("ROUND")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(NFGTheme.muted)
                Text("#\(result.roundId)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(NFGTheme.accent)
            }

            HStack(spacing: 8) {
                Text("💥")
                    .font(.system(size: 22))
                Text("Crashed at")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(NFGTheme.muted)
                Text(String(format: "%.2f×", result.crashPoint))
                    .font(NFGFont.multiplier(28, weight: .black))
                    .foregroundStyle(NFGTheme.danger)
                    .shadow(color: NFGTheme.danger.opacity(0.45), radius: 8)
            }

            HStack(spacing: 12) {
                resultBadge(count: result.wins.count, label: "won", color: NFGTheme.accent2, icon: "checkmark")
                resultBadge(count: result.losses.count, label: "lost", color: NFGTheme.danger, icon: "xmark")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, personal == nil ? NFGSpacing.lg : NFGSpacing.sm)
        .background(
            LinearGradient(
                colors: [NFGTheme.panel2, NFGTheme.panel],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func resultBadge(count: Int, label: String, color: Color, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            Text("\(count) \(label)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.15)))
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }

    private func outcomeSection(title: String, icon: String, color: Color, rows: [RoundOutcome]) -> some View {
        VStack(alignment: .leading, spacing: NFGSpacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title.uppercased())
                    .font(NFGFont.eyebrow(11))
                    .tracking(1.4)
            }
            .foregroundStyle(color)

            ForEach(rows) { row in
                outcomeRow(row, accent: color)
            }
        }
    }

    @ViewBuilder
    private func outcomeRow(_ row: RoundOutcome, accent: Color) -> some View {
        let isYou = row.user.lowercased() == AuthStore.verifiedUserId.lowercased()
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(row.resolvedName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                        .lineLimit(1)
                    if isYou {
                        Text("YOU")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(NFGTheme.gold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(NFGTheme.gold.opacity(0.2)))
                    }
                }
                if let bet = row.bet, let target = row.cashout {
                    Text("Bet \(formatPoints(bet)) @ \(String(format: "%.2f", target))×")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(NFGTheme.muted)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if row.isWin, let payout = row.payout ?? row.grossPayout {
                    Text("+\(formatPoints(payout))")
                        .font(NFGFont.numeric(15, weight: .heavy))
                        .foregroundStyle(NFGTheme.accent2)
                } else {
                    Text("BUSTED")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(NFGTheme.danger)
                }
            }
        }
        .padding(NFGSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.md)
                .fill(isYou ? accent.opacity(0.14) : accent.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.md)
                .stroke(isYou ? accent.opacity(0.45) : accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func formatPoints(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
