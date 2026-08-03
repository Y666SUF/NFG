import SwiftUI

/// Side-by-side mock screens for the proposed **Vault Terminal** look.
/// Nothing here is wired into production views — open from Settings → Preview new look.
struct VisualOverhaulPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var useProposed = true
    @State private var screen: PreviewScreen = .crash

    private enum PreviewScreen: String, CaseIterable, Identifiable {
        case crash = "Crash"
        case wallet = "Wallet"
        case arcade = "Arcade"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Theme", selection: $useProposed) {
                    Text("Current").tag(false)
                    Text("Vault Terminal").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                Picker("Screen", selection: $screen) {
                    ForEach(PreviewScreen.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                Text(useProposed ? proposedBlurb : currentBlurb)
                    .font(.caption)
                    .foregroundStyle(previewMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                phoneFrame {
                    switch screen {
                    case .crash: crashMock
                    case .wallet: walletMock
                    case .arcade: arcadeMock
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .background(previewBackground.ignoresSafeArea())
            .navigationTitle("Visual preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var currentBlurb: String {
        "Navy vault, cyan + mint accents, purple chart glow, rounded chips."
    }

    private var proposedBlurb: String {
        "Warm charcoal, amber primary, tighter corners, flatter panels, less gradient noise."
    }

    // MARK: - Theme accessors

    private var previewBackground: Color {
        useProposed ? NFGThemeVaultTerminal.background : NFGTheme.background
    }

    private var previewPanel: Color {
        useProposed ? NFGThemeVaultTerminal.panel : NFGTheme.panel
    }

    private var previewText: Color {
        useProposed ? NFGThemeVaultTerminal.text : NFGTheme.text
    }

    private var previewMuted: Color {
        useProposed ? NFGThemeVaultTerminal.muted : NFGTheme.muted
    }

    private var previewAccent: Color {
        useProposed ? NFGThemeVaultTerminal.accent : NFGTheme.accent
    }

    private var previewAccent2: Color {
        useProposed ? NFGThemeVaultTerminal.accent2 : NFGTheme.accent2
    }

    private var previewDanger: Color {
        useProposed ? NFGThemeVaultTerminal.danger : NFGTheme.danger
    }

    private var previewGold: Color {
        useProposed ? NFGThemeVaultTerminal.gold : NFGTheme.gold
    }

    private var previewBorder: Color {
        useProposed ? NFGThemeVaultTerminal.border : NFGTheme.border
    }

    private var previewRadius: CGFloat {
        useProposed ? NFGVaultTerminalRadius.md : NFGRadius.md
    }

    private var previewAccentGradient: LinearGradient {
        useProposed ? NFGThemeVaultTerminal.accentGradient : NFGTheme.accentGradient
    }

    private var previewLineGradient: LinearGradient {
        useProposed ? NFGThemeVaultTerminal.lineGradient : NFGTheme.lineGradient
    }

    private var previewChartFill: LinearGradient {
        useProposed ? NFGThemeVaultTerminal.chartFill : NFGTheme.chartFill
    }

    // MARK: - Phone chrome

    private func phoneFrame<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 72, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                content()
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(8)
        }
        .aspectRatio(9 / 19.5, contentMode: .fit)
        .frame(maxHeight: 520)
    }

    // MARK: - Crash mock

    private var crashMock: some View {
        ZStack {
            previewBackground

            if useProposed {
                NFGThemeVaultTerminal.backgroundGlow.opacity(0.9)
            } else {
                NFGTheme.backgroundGlow.opacity(0.9)
            }

            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NFG CRASH")
                            .font(labelFont(size: 11))
                            .foregroundStyle(previewMuted)
                        Text("Round #4821")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(previewMuted.opacity(0.8))
                    }
                    Spacer()
                    balanceChip(amount: "12,450")
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)

                chartMock
                    .frame(height: 130)
                    .padding(.horizontal, 12)

                HStack(spacing: 6) {
                    crashPill("1.42×", muted: true)
                    crashPill("2.08×", muted: true)
                    crashPill("1.03×", muted: true)
                    crashPill("4.71×", muted: false)
                }
                .padding(.horizontal, 12)

                Spacer(minLength: 0)

                betDockMock
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
        }
    }

    private var chartMock: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: previewRadius, style: .continuous)
                .fill(previewPanel.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: previewRadius, style: .continuous)
                        .stroke(previewBorder, lineWidth: 1)
                )

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack(alignment: .bottomLeading) {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h * 0.82))
                        path.addCurve(
                            to: CGPoint(x: w, y: h * 0.18),
                            control1: CGPoint(x: w * 0.35, y: h * 0.78),
                            control2: CGPoint(x: w * 0.62, y: h * 0.42)
                        )
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(previewChartFill)

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: h * 0.82))
                        path.addCurve(
                            to: CGPoint(x: w, y: h * 0.18),
                            control1: CGPoint(x: w * 0.35, y: h * 0.78),
                            control2: CGPoint(x: w * 0.62, y: h * 0.42)
                        )
                    }
                    .stroke(previewLineGradient, style: StrokeStyle(lineWidth: useProposed ? 2.5 : 2, lineCap: .round))
                }
            }
            .padding(10)

            Text("2.45×")
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .foregroundStyle(previewAccentGradient)
                .padding(12)
        }
    }

    private func crashPill(_ value: String, muted: Bool) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(muted ? previewMuted : previewDanger)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(muted ? previewPanel : previewDanger.opacity(0.15))
            )
            .overlay(Capsule().stroke(muted ? previewBorder : previewDanger.opacity(0.35), lineWidth: 1))
    }

    private var betDockMock: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                fieldMock(label: "Bet", value: "100")
                fieldMock(label: "Auto @", value: "2.00")
            }
            Button {} label: {
                Text("PLACE BET")
                    .font(labelFont(size: 14))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: previewRadius, style: .continuous)
                            .fill(previewAccentGradient)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: previewRadius + 2, style: .continuous)
                .fill(useProposed ? NFGThemeVaultTerminal.betDockBackground : NFGTheme.betDockBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: previewRadius + 2, style: .continuous)
                .stroke(previewBorder, lineWidth: 1)
        )
    }

    private func fieldMock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(labelFont(size: 9))
                .foregroundStyle(previewMuted)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(previewText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: previewRadius, style: .continuous)
                .fill(useProposed ? NFGThemeVaultTerminal.inputBackground : NFGTheme.inputBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: previewRadius, style: .continuous)
                .stroke(previewBorder, lineWidth: 1)
        )
    }

    // MARK: - Wallet mock

    private var walletMock: some View {
        ZStack {
            previewBackground
            VStack(alignment: .leading, spacing: 14) {
                Text("Wallet")
                    .font(labelFont(size: 20))
                    .foregroundStyle(previewText)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 6) {
                    Text("BALANCE")
                        .font(labelFont(size: 10))
                        .foregroundStyle(previewMuted)
                    Text("12,450")
                        .font(.system(size: 34, weight: .heavy, design: .monospaced))
                        .foregroundStyle(previewAccent)
                    Text("Vault points")
                        .font(.caption)
                        .foregroundStyle(previewAccent2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(cardBackground)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent")
                        .font(labelFont(size: 13))
                        .foregroundStyle(previewText)
                    walletRow(title: "Crash win", amount: "+240", positive: true)
                    walletRow(title: "Jump VS entry", amount: "-50", positive: false)
                    walletRow(title: "Daily reward", amount: "+25", positive: true)
                }
                .padding(14)
                .background(cardBackground)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: useProposed ? NFGVaultTerminalRadius.lg : NFGRadius.lg, style: .continuous)
            .fill(useProposed ? AnyShapeStyle(NFGThemeVaultTerminal.panelGradient) : AnyShapeStyle(NFGTheme.panelGradient))
            .overlay(
                RoundedRectangle(cornerRadius: useProposed ? NFGVaultTerminalRadius.lg : NFGRadius.lg, style: .continuous)
                    .stroke(previewBorder, lineWidth: 1)
            )
    }

    private func walletRow(title: String, amount: String, positive: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(previewText)
            Spacer()
            Text(amount)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(positive ? previewAccent2 : previewDanger)
        }
    }

    // MARK: - Arcade mock

    private var arcadeMock: some View {
        ZStack {
            previewBackground
            VStack(alignment: .leading, spacing: 12) {
                Text("Arcade")
                    .font(labelFont(size: 20))
                    .foregroundStyle(previewText)
                    .padding(.top, 14)

                Text("Skill games · stake optional")
                    .font(.caption)
                    .foregroundStyle(previewMuted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    arcadeTile(title: "Jump", subtitle: "VS live", tint: previewAccent2)
                    arcadeTile(title: "Blocks", subtitle: "Solo", tint: previewAccent)
                    arcadeTile(title: "Vault Run", subtitle: "Staked", tint: previewGold)
                    arcadeTile(title: "Tower", subtitle: "Practice", tint: previewMuted)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
        }
    }

    private func arcadeTile(title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: previewRadius, style: .continuous)
                .fill(tint.opacity(useProposed ? 0.18 : 0.22))
                .frame(height: 54)
                .overlay(
                    Text(String(title.prefix(1)))
                        .font(.system(size: 22, weight: .heavy, design: useProposed ? .default : .rounded))
                        .foregroundStyle(tint)
                )
            Text(title)
                .font(labelFont(size: 13))
                .foregroundStyle(previewText)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(previewMuted)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: - Shared bits

    private func balanceChip(amount: String) -> some View {
        HStack(spacing: 4) {
            Text(amount)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            Text("pts")
                .font(labelFont(size: 10))
                .foregroundStyle(previewMuted)
        }
        .foregroundStyle(previewGold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(previewGold.opacity(0.14)))
        .overlay(Capsule().stroke(previewGold.opacity(0.35), lineWidth: 1))
    }

    private func labelFont(size: CGFloat) -> Font {
        if useProposed {
            return .system(size: size, weight: .semibold)
        }
        return .system(size: size, weight: .semibold, design: .rounded)
    }
}

#Preview {
    VisualOverhaulPreviewView()
}
