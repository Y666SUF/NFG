import SwiftUI

/// Phase + multiplier (toolbar or in-game).
struct GameMultiplierBadge: View {
    let phase: GamePhase
    let multiplier: Double
    var compact: Bool = false

    private var phaseLabel: String {
        switch phase {
        case .idle: return "Idle"
        case .betting: return "Betting"
        case .running: return "Flying"
        case .ended: return "Crashed"
        }
    }

    private var multColor: Color {
        phase == .ended ? NFGTheme.danger : NFGTheme.accent
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(phaseLabel.uppercased())
                .font(.system(size: compact ? 7 : 8, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.muted)
            Text(String(format: "%.2f×", multiplier))
                .font(.system(size: compact ? 18 : 24, weight: .heavy, design: .monospaced))
                .foregroundStyle(multColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}
