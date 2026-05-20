import SwiftUI

struct RoundResultPopupView: View {
    let result: RoundResultSummary
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !result.wins.isEmpty {
                            outcomeSection(title: "Winners", icon: "checkmark.circle.fill", color: NFGTheme.accent2, rows: result.wins)
                        }
                        if !result.losses.isEmpty {
                            outcomeSection(title: "Lost", icon: "xmark.circle.fill", color: NFGTheme.danger, rows: result.losses)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(maxHeight: 360)

                Button("Continue") { onDismiss() }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NFGTheme.accent)
                    .foregroundStyle(.white)
            }
            .background(NFGTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(NFGTheme.border))
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.45), radius: 24, y: 8)
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Round \(result.roundId) results")
                .font(.headline)
                .foregroundStyle(NFGTheme.text)
            Text("Crashed at \(String(format: "%.2f", result.crashPoint))×")
                .font(.title2.bold())
                .foregroundStyle(NFGTheme.danger)
            Text("\(result.wins.count) won · \(result.losses.count) lost")
                .font(.caption)
                .foregroundStyle(NFGTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(NFGTheme.panel2)
    }

    private func outcomeSection(title: String, icon: String, color: Color, rows: [RoundOutcome]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundStyle(color)

            ForEach(rows) { row in
                outcomeRow(row, accent: color)
            }
        }
    }

    private func outcomeRow(_ row: RoundOutcome, accent: Color) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.resolvedName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NFGTheme.text)
                    .lineLimit(1)
                if let bet = row.bet, let target = row.cashout {
                    Text("Bet \(formatPoints(bet)) @ \(String(format: "%.2f", target))×")
                        .font(.caption)
                        .foregroundStyle(NFGTheme.muted)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if row.isWin, let payout = row.payout ?? row.grossPayout {
                    Text("+\(formatPoints(payout))")
                        .font(.subheadline.bold())
                        .foregroundStyle(NFGTheme.accent2)
                } else {
                    Text("Busted")
                        .font(.subheadline.bold())
                        .foregroundStyle(NFGTheme.danger)
                }
            }
        }
        .padding(10)
        .background(NFGTheme.panel2.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.25)))
    }

    private func formatPoints(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
    }
}
