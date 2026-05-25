import SwiftUI

struct RoundResultPopupView: View {
    let result: RoundResultSummary
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Backdrop with subtle radial flash
            ZStack {
                Color.black.opacity(0.78)
                    .ignoresSafeArea()
                RadialGradient(
                    colors: [NFGTheme.danger.opacity(0.25), .clear],
                    center: .top,
                    startRadius: 0,
                    endRadius: 380
                )
                .ignoresSafeArea()
            }
            .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
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
                .frame(maxHeight: 380)

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
            .shadow(color: NFGTheme.danger.opacity(0.15), radius: 24)
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
        .padding(.vertical, NFGSpacing.lg)
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

    private func outcomeRow(_ row: RoundOutcome, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.resolvedName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(NFGTheme.text)
                    .lineLimit(1)
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
                .fill(accent.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.md)
                .stroke(accent.opacity(0.28), lineWidth: 1)
        )
    }

    private func formatPoints(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
