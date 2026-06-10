import SwiftUI

enum VaultRunObstacleColorsBridge {
    static let asteroid = Color(red: 0.95, green: 0.28, blue: 0.24)
    static let debris = Color(red: 1, green: 0.62, blue: 0.18)
    static let tunnel = Color(red: 0.62, green: 0.42, blue: 0.98)
}

typealias VaultRunShopOutcome = SnakeJumpShopOutcome

struct VaultRunShopButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
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
                            colors: [VaultRunTheme.accentGold, VaultRunTheme.accentGold.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
            .shadow(color: VaultRunTheme.accentGold.opacity(0.45), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct VaultRunObstacleLegend: View {
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !compact {
                Label("Obstacles", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NFGTheme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    legendChip(color: VaultRunObstacleColorsBridge.asteroid, label: "Asteroid", icon: "xmark", hint: "Dodge")
                    legendChip(color: VaultRunObstacleColorsBridge.debris, label: "Debris", icon: "arrow.up", hint: "Boost ↑")
                    legendChip(color: VaultRunObstacleColorsBridge.tunnel, label: "Rock tunnel", icon: "arrow.down", hint: "Shrink ↓")
                }
            }
        }
        .padding(compact ? 8 : 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(NFGTheme.panel.opacity(compact ? 0.88 : 0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NFGTheme.border.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func legendChip(color: Color, label: String, icon: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color)
                    .frame(width: 12, height: 9)
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(NFGTheme.text)
            }
            Text(hint)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(NFGTheme.panel2.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct VaultRunCollapsibleObstacleLegend: View {
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if expanded {
                VaultRunObstacleLegend(compact: true)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: expanded ? "chevron.down.circle.fill" : "questionmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(expanded ? "Hide" : "Obstacles")
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundStyle(expanded ? NFGTheme.muted : VaultRunTheme.accentGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(
                            expanded ? NFGTheme.border.opacity(0.35) : VaultRunTheme.accentGold.opacity(0.45),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .padding(.top, expanded ? 6 : 0)
        }
    }
}

struct VaultRunShopShipPreview: View {
    let hullHex: String
    let cockpitHex: String
    let trailHex: String
    let style: String
    let shipId: String

    @State private var glow = false

    private var tier: Int { VaultRunShopCatalog.trailTier(for: shipId) }

    var body: some View {
        ZStack {
            if tier > 0 {
                Capsule()
                    .fill(Color.vaultRunHexOptional(trailHex) ?? VaultRunTheme.accentOrange)
                    .frame(width: 10, height: 22)
                    .offset(y: 14)
                    .blur(radius: 3)
                    .opacity(glow ? 0.85 : 0.45)
            }
            VaultRunDraw.previewPath(style: style, in: CGRect(x: 0, y: 0, width: 34, height: 28))
                .fill(Color.vaultRunHexOptional(hullHex) ?? VaultRunTheme.accentGold)
                .frame(width: 34, height: 28)
            VaultRunDraw.previewPath(style: style, in: CGRect(x: 0, y: 0, width: 34, height: 28))
                .stroke(Color.vaultRunHexOptional(cockpitHex) ?? VaultRunTheme.accentOrange, lineWidth: 1.5)
                .frame(width: 34, height: 28)
            Circle()
                .fill(Color.vaultRunHexOptional(cockpitHex) ?? VaultRunTheme.accentOrange)
                .frame(width: 8, height: 8)
                .offset(y: -4)
        }
        .frame(width: 48, height: 48)
        .onAppear {
            guard tier > 0 else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

struct VaultRunShopSheet: View {
    let balance: Int
    let items: [VaultRunShipItem]
    let busy: Bool
    var onBuy: (String) async -> VaultRunShopOutcome
    var onEquip: (String) async -> VaultRunShopOutcome

    @Environment(\.dismiss) private var dismiss
    @State private var shopMessage: String?
    @State private var shopError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "airplane.circle.fill")
                                .foregroundStyle(VaultRunTheme.accentGold)
                            Text("NFG RUSH HANGAR")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundStyle(NFGTheme.text)
                        }
                        Text("Spend Crash points on ship hulls, cockpit glow, and colored engine trails. Your equipped ship shows in-game.")
                            .font(.system(size: 12))
                            .foregroundStyle(NFGTheme.muted)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(NFGTheme.panel2.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(VaultRunTheme.accentGold.opacity(0.3), lineWidth: 1)
                            )
                    )
                    HStack {
                        Image(systemName: "star.circle.fill")
                            .foregroundStyle(VaultRunTheme.accentGold)
                        Text("Balance: \(balance.formatted()) pts")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(NFGTheme.text)
                    }
                    if let shopError, !shopError.isEmpty {
                        Text(shopError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NFGTheme.danger)
                    } else if let shopMessage, !shopMessage.isEmpty {
                        Text(shopMessage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(NFGTheme.accent2)
                    }
                    ForEach(items) { item in
                        shopRow(item)
                    }
                }
                .padding()
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle("Hangar Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func shopRow(_ item: VaultRunShipItem) -> some View {
        let owned = item.owned == true
        let equipped = item.equipped == true
        HStack(spacing: 12) {
            VaultRunShopShipPreview(
                hullHex: item.hull,
                cockpitHex: item.cockpit,
                trailHex: item.trail,
                style: item.style,
                shipId: item.id
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
                if let desc = item.desc, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(NFGTheme.muted)
                }
                if VaultRunShopCatalog.trailTier(for: item.id) > 0 {
                    Text("Unlocks richer engine trail")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VaultRunTheme.accentOrange)
                }
                Text(item.cost == 0 ? "Free" : "\(item.cost.formatted()) pts")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(item.cost == 0 ? NFGTheme.muted : NFGTheme.gold)
            }
            Spacer(minLength: 0)
            if equipped {
                Text("Equipped")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(NFGTheme.accent2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(NFGTheme.panel2)
                    .clipShape(Capsule())
            } else if owned {
                Button(busy ? "…" : "Equip") {
                    Task {
                        switch await onEquip(item.id) {
                        case .success(let msg):
                            shopMessage = msg
                            shopError = nil
                        case .failure(let msg):
                            shopError = msg
                            shopMessage = nil
                        }
                    }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NFGTheme.accent2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NFGTheme.panel2)
                .clipShape(Capsule())
                .disabled(busy)
            } else {
                Button(busy ? "…" : "Buy") {
                    Task {
                        switch await onBuy(item.id) {
                        case .success(let msg):
                            shopMessage = msg
                            shopError = nil
                        case .failure(let msg):
                            shopError = msg
                            shopMessage = nil
                        }
                    }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(balance >= item.cost ? NFGTheme.gold : NFGTheme.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(NFGTheme.panel2)
                .clipShape(Capsule())
                .disabled(busy || balance < item.cost)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(NFGTheme.panel.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(equipped ? VaultRunTheme.accentGold.opacity(0.5) : NFGTheme.border.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private extension Color {
    static func vaultRunHexOptional(_ hex: String) -> Color? {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}
