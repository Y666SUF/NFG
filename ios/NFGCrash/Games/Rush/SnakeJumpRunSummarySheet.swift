import SwiftUI

enum SnakeJumpShopOutcome {
    case success(String)
    case failure(String)
}

struct SnakeJumpRunSummarySheet: View {
    let peakHeight: Int
    let pointsEarned: Int
    var jumpTotalEarned: Int?
    let personalBest: Int
    let isNewBest: Bool
    var onPlayAgain: (() async -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Run Complete")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
            if onPlayAgain != nil {
                Text("House wins this round — spin up another run?")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)
            }
            if isNewBest {
                Label("New personal best!", systemImage: "trophy.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VaultRunTheme.accentGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(VaultRunTheme.accentGold.opacity(0.12))
                    .clipShape(Capsule())
            }
            HStack(spacing: 12) {
                summaryTile(label: "Peak", value: "\(peakHeight.formatted())m", accent: VaultRunTheme.accentOrange)
                summaryTile(
                    label: jumpTotalEarned == nil ? "Earned" : "This run",
                    value: "+\(pointsEarned.formatted())",
                    accent: VaultRunTheme.accentJade
                )
                if let jumpTotalEarned {
                    summaryTile(label: "Jump total", value: jumpTotalEarned.formatted(), accent: VaultRunTheme.accentGold)
                } else {
                    summaryTile(label: "Best", value: "\(personalBest.formatted())m", accent: VaultRunTheme.accentGold)
                }
            }
            if jumpTotalEarned != nil {
                Text("Best height: \(personalBest.formatted())m")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NFGTheme.muted)
            }
            if let onPlayAgain {
                Button {
                    Task {
                        await onPlayAgain()
                        dismiss()
                    }
                } label: {
                    Text("Play Again")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [VaultRunTheme.accentOrange, VaultRunTheme.accentGold],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NFGTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.88))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [VaultRunTheme.accentGold, VaultRunTheme.accentGold.opacity(0.75)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(NFGTheme.panel.ignoresSafeArea())
        .presentationDetents([.height(onPlayAgain != nil ? 320 : (jumpTotalEarned == nil ? 260 : 300))])
        .presentationDragIndicator(.visible)
    }

    private func summaryTile(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            Text(value)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(NFGTheme.panel2.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
