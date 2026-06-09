import SwiftUI

struct ChartEntriesOverlay: View {
    let openBets: [OpenBet]
    let queuedBets: [OpenBet]
    let lastActionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let lastActionMessage, !lastActionMessage.isEmpty {
                Text(lastActionMessage)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(NFGTheme.accent2)
                    .chartOverlayTextLegibility()
            }
            ForEach(openBets.prefix(4)) { bet in
                entryRow(bet, queued: false)
            }
            ForEach(queuedBets.prefix(3)) { bet in
                entryRow(bet, queued: true)
            }
        }
    }

    private func entryRow(_ bet: OpenBet, queued: Bool) -> some View {
        HStack(spacing: 4) {
            Text(queued ? "Q" : "•")
            Text(bet.displayName.isEmpty ? bet.user : bet.displayName)
                .lineLimit(1)
            Text("\(bet.amount)")
            if bet.cashout > 0 {
                Text("@\(String(format: "%.2f", bet.cashout))x")
            }
        }
        .font(.system(size: 8, weight: .bold, design: .monospaced))
        .foregroundStyle(queued ? NFGTheme.muted : NFGTheme.text)
        .chartOverlayTextLegibility()
    }
}

extension View {
    func chartOverlayTextLegibility() -> some View {
        shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.55), radius: 6, x: 0, y: 0)
    }
}
