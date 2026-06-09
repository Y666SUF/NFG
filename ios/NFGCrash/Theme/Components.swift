import SwiftUI

// MARK: - Card modifier
//
// One unified card recipe used across the app: navy panel fill, hairline
// gradient border, soft shadow. Use `.nfgCard()` on any view.

struct NFGCardModifier: ViewModifier {
    var radius: CGFloat = NFGRadius.lg
    var padding: CGFloat = NFGSpacing.md
    var fill: AnyShapeStyle = AnyShapeStyle(NFGTheme.panelGradient)
    var borderColor: Color? = nil
    var glow: Color? = nil
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        borderColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(NFGTheme.hairlineBorder),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: (glow ?? Color.black).opacity(glow == nil ? (elevated ? 0.45 : 0.25) : 0.35),
                radius: elevated ? 18 : 10,
                x: 0,
                y: elevated ? 8 : 4
            )
    }
}

extension View {
    /// Premium card chrome — gradient fill, hairline border, soft shadow.
    func nfgCard(
        radius: CGFloat = NFGRadius.lg,
        padding: CGFloat = NFGSpacing.md,
        fill: AnyShapeStyle? = nil,
        borderColor: Color? = nil,
        glow: Color? = nil,
        elevated: Bool = false
    ) -> some View {
        modifier(NFGCardModifier(
            radius: radius,
            padding: padding,
            fill: fill ?? AnyShapeStyle(NFGTheme.panelGradient),
            borderColor: borderColor,
            glow: glow,
            elevated: elevated
        ))
    }
}

// MARK: - Primary / secondary buttons

struct NFGPrimaryButtonStyle: ButtonStyle {
    var tintGradient: LinearGradient = NFGTheme.accentGradient
    var glowColor: Color = NFGTheme.accent
    var isDisabled: Bool = false
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .heavy, design: .rounded))
            .foregroundStyle(isDisabled ? NFGTheme.muted : Color.black.opacity(0.92))
            .frame(maxWidth: .infinity)
            .padding(.vertical, compact ? 10 : 13)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                        .fill(isDisabled ? AnyShapeStyle(NFGTheme.panel) : AnyShapeStyle(tintGradient))
                    RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.18), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .blendMode(.plusLighter)
                        .opacity(isDisabled ? 0 : 1)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                    .stroke(Color.white.opacity(isDisabled ? 0.05 : 0.25), lineWidth: 1)
            )
            .shadow(
                color: isDisabled ? .clear : glowColor.opacity(configuration.isPressed ? 0.25 : 0.55),
                radius: configuration.isPressed ? 6 : 12,
                y: configuration.isPressed ? 1 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct NFGSecondaryButtonStyle: ButtonStyle {
    var tint: Color = NFGTheme.accent2
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 14, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 9 : 12)
            .background(
                RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                    .fill(NFGTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                    .stroke(tint.opacity(configuration.isPressed ? 0.55 : 0.32), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Section header

struct NFGSectionHeader: View {
    let title: String
    var icon: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NFGTheme.accent2)
            }
            Text(title.uppercased())
                .font(NFGFont.eyebrow(11))
                .tracking(1.2)
                .foregroundStyle(NFGTheme.muted)
            Spacer(minLength: 6)
            if let trailing { trailing }
        }
    }
}

// MARK: - Chip

struct NFGChip: View {
    let text: String
    var icon: String? = nil
    var tint: Color = NFGTheme.accent
    var filled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(filled ? Color.black.opacity(0.88) : tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)))
        )
        .overlay(
            Capsule().stroke(tint.opacity(filled ? 0 : 0.4), lineWidth: 1)
        )
    }
}

// MARK: - Multiplier text

/// Big monospaced multiplier readout with phase-aware glow.
struct NFGMultiplierText: View {
    let value: Double
    var size: CGFloat = 30
    var phase: GamePhase = .idle

    private var color: Color {
        switch phase {
        case .ended: return NFGTheme.danger
        case .running: return NFGTheme.accent
        case .betting: return NFGTheme.accent2
        case .idle: return NFGTheme.muted
        }
    }

    var body: some View {
        Text(String(format: "%.2f×", value))
            .font(NFGFont.multiplier(size))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.45), radius: 10)
            .contentTransition(.numericText(value: value))
    }
}

// MARK: - Phase badge (eyebrow above multiplier)

struct NFGPhaseBadge: View {
    let phase: GamePhase

    private var label: String {
        switch phase {
        case .idle: return "Idle"
        case .betting: return "Betting"
        case .running: return "Flying"
        case .ended: return "Crashed"
        }
    }

    private var color: Color {
        switch phase {
        case .idle: return NFGTheme.muted
        case .betting: return NFGTheme.accent2
        case .running: return NFGTheme.accent
        case .ended: return NFGTheme.danger
        }
    }

    private var icon: String {
        switch phase {
        case .idle: return "moon.zzz.fill"
        case .betting: return "hourglass"
        case .running: return "airplane"
        case .ended: return "burst.fill"
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(1.3)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 0.8))
    }
}

// MARK: - Pulse dot (used by LIVE badge)

struct NFGPulseDot: View {
    var color: Color = .red
    var size: CGFloat = 8

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.55), lineWidth: 2)
                .frame(width: size * 2.3, height: size * 2.3)
                .scaleEffect(pulse ? 1.0 : 0.5)
                .opacity(pulse ? 0 : 0.85)
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.8), radius: 5)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Background ambient layer

/// Reusable atmospheric backdrop for the game / scene screens.
struct NFGSceneBackground: View {
    var phase: GamePhase = .idle
    var multiplier: Double = 1

    private var runningStrength: Double {
        guard phase == .running else { return 0 }
        // Build to a peak gently — never burns out the screen.
        return min(0.55, 0.18 + (multiplier - 1) * 0.08)
    }

    var body: some View {
        ZStack {
            NFGTheme.background.ignoresSafeArea()

            NFGTheme.backgroundGlow
                .ignoresSafeArea()
                .opacity(phase == .ended ? 0.3 : 1)

            // Soft cyan rising glow while flying.
            RadialGradient(
                colors: [NFGTheme.accent.opacity(runningStrength), .clear],
                center: .bottom,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.4), value: runningStrength)

            if phase == .ended {
                RadialGradient(
                    colors: [NFGTheme.danger.opacity(0.32), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 340
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Convenience input field style

struct NFGFieldBackground: ViewModifier {
    var focused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, NFGSpacing.md)
            .padding(.vertical, NFGSpacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                    .fill(NFGTheme.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                    .stroke(focused ? NFGTheme.accent.opacity(0.7) : NFGTheme.border, lineWidth: 1)
            )
            .animation(.easeOut(duration: 0.15), value: focused)
    }
}

extension View {
    func nfgInputBackground(focused: Bool = false) -> some View {
        modifier(NFGFieldBackground(focused: focused))
    }
}
