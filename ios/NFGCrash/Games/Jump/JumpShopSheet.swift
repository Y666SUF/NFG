import SwiftUI

struct JumpShopSheet: View {
    let balance: Int
    let items: [JumpShopItem]
    let onBuy: (String) async -> SnakeJumpShopOutcome
    let onEquip: (String) async -> SnakeJumpShopOutcome
    let onDismiss: () -> Void

    @State private var shopMessage = ""
    @State private var shopError = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Circle Shop")
                                .font(.system(size: 20, weight: .bold))
                            Text("Premium casino chips for your jump circle")
                                .font(.system(size: 12))
                                .foregroundStyle(NFGTheme.muted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Balance")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(NFGTheme.muted)
                            Text("\(balance.formatted()) pts")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(NFGTheme.gold)
                        }
                    }
                    .padding(.horizontal, 4)

                    if !shopError.isEmpty {
                        Text(shopError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NFGTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if !shopMessage.isEmpty {
                        Text(shopMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NFGTheme.accent2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(items) { item in
                        shopRow(item)
                    }
                }
                .padding(16)
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: onDismiss)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private func shopRow(_ item: JumpShopItem) -> some View {
        let tier = shopTier(for: item)
        let premium = (item.cost ?? 0) >= 3_500_000
        return HStack(spacing: 14) {
            ZStack {
                if premium {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: tier.colors + [tier.colors.first ?? NFGTheme.gold],
                                center: .center
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: 60, height: 60)
                        .opacity(0.85)
                }
                JumpCirclePreview(
                    fill: item.fill ?? "#596ff2",
                    ring: item.ring ?? "#f2c733",
                    size: 52,
                    shimmer: premium && item.owned == true
                )
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name ?? item.id)
                        .font(.system(size: 15, weight: .bold))
                    Text(tier.label)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.black.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(colors: tier.colors, startPoint: .leading, endPoint: .trailing)
                                )
                        )
                }
                Text(item.desc ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(2)
                if let cost = item.cost, cost > 0, item.owned != true {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(NFGTheme.gold)
                        Text("\(cost.formatted()) pts")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NFGTheme.gold)
                    }
                }
            }
            Spacer(minLength: 8)
            shopAction(for: item)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            NFGTheme.panel,
                            premium ? NFGTheme.panel.opacity(0.82) : NFGTheme.panel,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    item.equipped == true
                        ? LinearGradient(colors: [NFGTheme.gold, NFGTheme.gold.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [NFGTheme.border.opacity(0.35), NFGTheme.border.opacity(0.2)], startPoint: .top, endPoint: .bottom),
                    lineWidth: item.equipped == true ? 1.5 : 1
                )
        )
        .shadow(color: premium ? NFGTheme.gold.opacity(0.12) : .clear, radius: 10, y: 3)
    }

    private func shopTier(for item: JumpShopItem) -> (label: String, colors: [Color]) {
        let cost = item.cost ?? 0
        if cost == 0 { return ("House", [Color.gray.opacity(0.5), Color.gray.opacity(0.3)]) }
        if cost >= 15_000_000 { return ("Inferno", [Color.orange, NFGTheme.gold]) }
        if cost >= 11_000_000 { return ("Whale", [Color.white.opacity(0.7), Color.gray]) }
        if cost >= 8_500_000 { return ("Elite", [Color.green, Color.mint]) }
        if cost >= 6_000_000 { return ("VIP", [Color.purple, Color.pink]) }
        if cost >= 3_500_000 { return ("High Limit", [NFGTheme.gold, Color.yellow]) }
        return ("Neon", [Color.cyan, Color.blue])
    }

    @ViewBuilder
    private func shopAction(for item: JumpShopItem) -> some View {
        if item.equipped == true {
            Text("Equipped")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NFGTheme.accent2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NFGTheme.accent2.opacity(0.15))
                .clipShape(Capsule())
        } else if item.owned == true {
            Button("Equip") {
                Task {
                    let outcome = await onEquip(item.id)
                    switch outcome {
                    case .success(let msg):
                        shopMessage = msg
                        shopError = ""
                    case .failure(let msg):
                        shopError = msg
                        shopMessage = ""
                    }
                }
            }
            .font(.system(size: 12, weight: .bold))
            .buttonStyle(.borderedProminent)
            .tint(NFGTheme.accent)
        } else {
            let cost = item.cost ?? 0
            Button(cost == 0 ? "Free" : "Buy") {
                Task {
                    let outcome = await onBuy(item.id)
                    switch outcome {
                    case .success(let msg):
                        shopMessage = msg
                        shopError = ""
                    case .failure(let msg):
                        shopError = msg
                        shopMessage = ""
                    }
                }
            }
            .font(.system(size: 12, weight: .bold))
            .buttonStyle(.borderedProminent)
            .tint(NFGTheme.gold)
            .disabled(balance < cost)
        }
    }
}

struct JumpCirclePreview: View {
    let fill: String
    let ring: String
    var size: CGFloat = 40
    var shimmer: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let phase = shimmer ? timeline.date.timeIntervalSinceReferenceDate : 0
            ZStack {
                if shimmer {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.clear,
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: size * 0.7
                            )
                        )
                        .scaleEffect(1 + 0.06 * sin(phase * 4))
                }
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                SnakeJumpTheme.swiftColor(hex: fill, fallback: NFGTheme.accent),
                                SnakeJumpTheme.swiftColor(hex: fill, fallback: NFGTheme.accent).opacity(0.65),
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: size * 0.55
                        )
                    )
                Circle()
                    .stroke(SnakeJumpTheme.swiftColor(hex: ring, fallback: NFGTheme.gold), lineWidth: max(2, size * 0.06))
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: shimmer
                                ? [Color.white.opacity(0.5), Color.clear, Color.white.opacity(0.35), Color.clear]
                                : [Color.clear],
                            center: .center,
                            angle: .degrees(phase * 120)
                        ),
                        lineWidth: shimmer ? 2 : 0
                    )
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: size * 0.28, height: size * 0.28)
                    .offset(x: -size * 0.14, y: -size * 0.16)
            }
            .frame(width: size, height: size)
            .shadow(color: SnakeJumpTheme.swiftColor(hex: fill, fallback: NFGTheme.accent).opacity(shimmer ? 0.5 : 0.35), radius: shimmer ? 12 : 8, y: 2)
        }
    }
}

struct JumpVsToggleButton: View {
    let isVS: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isVS ? "person.2.fill" : "person.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(isVS ? "VS ON" : "VS")
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundStyle(isVS ? Color.white : Color.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isVS
                                ? [Color(red: 0.85, green: 0.15, blue: 0.35), Color(red: 0.55, green: 0.08, blue: 0.22)]
                                : [Color(red: 0.18, green: 0.22, blue: 0.34), Color(red: 0.10, green: 0.12, blue: 0.20)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(isVS ? Color.white.opacity(0.45) : NFGTheme.border.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: isVS ? Color.red.opacity(0.35) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isVS ? "VS mode on" : "Switch to VS mode")
    }
}

struct JumpShopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Shop")
                    .font(.system(size: 11, weight: .heavy))
            }
            .foregroundStyle(.black.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [NFGTheme.gold, NFGTheme.gold.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: NFGTheme.gold.opacity(0.45), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
