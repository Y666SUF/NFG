import SwiftUI

struct TowerCharacterAvatar: View {
    enum Pose {
        case idle
        case attack
        case hurt
    }

    let appearance: TowerCharacterAppearance
    let loadout: TowerGearLoadout
    var size: CGFloat = 64
    var pose: Pose = .idle
    var facingRight: Bool = true

    private var skinColor: Color {
        let palette: [Color] = [
            Color(red: 0.96, green: 0.82, blue: 0.71),
            Color(red: 0.91, green: 0.72, blue: 0.59),
            Color(red: 0.78, green: 0.53, blue: 0.26),
            Color(red: 0.55, green: 0.33, blue: 0.14),
        ]
        let idx = max(0, min(palette.count - 1, appearance.skinTone))
        return palette[idx]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.14)
                .fill(NFGTheme.panel2)
                .frame(width: size * 0.62, height: size * 0.52)
                .offset(y: size * 0.1)
            Circle()
                .fill(skinColor)
                .frame(width: size * 0.42, height: size * 0.42)
                .offset(y: -size * 0.14)
            if pose == .attack {
                Image(systemName: "bolt.fill")
                    .font(.system(size: size * 0.18, weight: .bold))
                    .foregroundStyle(NFGTheme.gold)
                    .offset(x: size * 0.28, y: -size * 0.05)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(x: facingRight ? 1 : -1, y: 1)
        .accessibilityLabel(appearance.heroName.isEmpty ? "Tower hero" : appearance.heroName)
    }
}
