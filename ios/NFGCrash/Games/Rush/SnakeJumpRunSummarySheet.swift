import SwiftUI

enum SnakeJumpShopOutcome {
    case success(String)
    case failure(String)
}

struct SnakeJumpRunSummarySheet: View {
    let peakHeight: Int
    let pointsEarned: Int
    let personalBest: Int
    let isNewBest: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Text("Run Complete")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(NFGTheme.text)
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
                summaryTile(label: "Earned", value: "+\(pointsEarned.formatted())", accent: VaultRunTheme.accentJade)
                summaryTile(label: "Best", value: "\(personalBest.formatted())m", accent: VaultRunTheme.accentGold)
            }
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
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(NFGTheme.panel.ignoresSafeArea())
        .presentationDetents([.height(260)])
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
