import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                NFGTheme.background.ignoresSafeArea()

                Group {
                    if sync.isLoadingLeaderboard && sync.fullBalances.isEmpty {
                        ProgressView("Loading balances…")
                            .tint(NFGTheme.accent)
                    } else if let err = sync.leaderboardError, sync.fullBalances.isEmpty {
                        ContentUnavailableView(
                            "Could not load leaderboard",
                            systemImage: "wifi.exclamationmark",
                            description: Text(err)
                        )
                    } else if sync.fullBalances.isEmpty {
                        ContentUnavailableView(
                            "No players yet",
                            systemImage: "person.3",
                            description: Text("Balances appear when players have points on the server.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                TopProfilesStrip(rows: sync.topBalances, compact: false)
                                    .padding(.bottom, 12)

                                Text(leaderboardListTitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(NFGTheme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 8)

                                ForEach(Array(sync.fullBalances.enumerated()), id: \.element.id) { index, row in
                                    LeaderboardRowView(row: row, position: index + 1, isYou: isCurrentUser(row))
                                    if index < sync.fullBalances.count - 1 {
                                        Divider().overlay(NFGTheme.border)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
            }
            .navigationTitle("Balances")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !sync.fullBalances.isEmpty {
                    Text(leaderboardHeader)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(NFGTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(NFGTheme.background.opacity(0.95))
                }
            }
            .toolbarBackground(NFGTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await sync.refreshLeaderboard() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(sync.isLoadingLeaderboard)
                }
            }
            .refreshable {
                await sync.refreshLeaderboard()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await sync.refreshLeaderboard()
        }
    }

    private var leaderboardHeader: String {
        let total = sync.leaderboardTotalCount
        let shown = sync.fullBalances.count
        if total > shown {
            return "Showing \(shown) of \(total) players"
        }
        if total > 0 {
            return "\(total) players total"
        }
        return "\(shown) players"
    }

    private var leaderboardListTitle: String {
        let total = sync.leaderboardTotalCount
        if total > 0 {
            return "All players (\(total))"
        }
        return "All balances (\(sync.fullBalances.count))"
    }

    private func isCurrentUser(_ row: LeaderboardRow) -> Bool {
        guard PlayerSession.isLoggedIn else { return false }
        return row.resolvedUser.lowercased() == PlayerSession.tiktokUsername.lowercased()
    }
}

struct TopProfilesStrip: View {
    let rows: [LeaderboardRow]
    var compact: Bool = true
    var onTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: compact ? 10 : 12, weight: .bold))
                        .foregroundStyle(NFGTheme.gold)
                    Text("TOP 5")
                        .font(NFGFont.eyebrow(compact ? 11 : 12))
                        .tracking(1.4)
                        .foregroundStyle(NFGTheme.muted)
                }
                Spacer()
                if onTap != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NFGTheme.muted)
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    if index < rows.count {
                        TopProfileCard(row: rows[index], position: index + 1, compact: compact)
                    } else {
                        RoundedRectangle(cornerRadius: NFGRadius.md)
                            .fill(NFGTheme.panel.opacity(0.35))
                            .frame(height: compact ? 56 : 92)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                RoundedRectangle(cornerRadius: NFGRadius.md)
                                    .stroke(NFGTheme.border.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            )
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap?()
        }
    }
}

struct TopProfileCard: View {
    let row: LeaderboardRow
    let position: Int
    var compact: Bool = true

    private var positionTint: Color {
        switch position {
        case 1: return NFGTheme.gold
        case 2: return NFGTheme.accent
        case 3: return NFGTheme.accent2
        default: return NFGTheme.muted
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            HStack(spacing: 4) {
                Text("#\(position)")
                    .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(positionTint)
                Spacer()
                if row.superFan == true {
                    Text("★")
                        .font(.system(size: compact ? 8 : 10))
                        .foregroundStyle(NFGTheme.gold)
                }
            }
            Text(row.resolvedDisplayName)
                .font(.system(size: compact ? 10 : 12, weight: .bold, design: .rounded))
                .foregroundStyle(NFGTheme.text)
                .lineLimit(1)
            if !compact {
                Text("@\(row.resolvedUser)")
                    .font(.system(size: 9))
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(1)
                Text("\(row.rank ?? "Rookie") · Lv \(row.level ?? 1)")
                    .font(.system(size: 8))
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(1)
            }
            Text(row.balance.formatted())
                .font(.system(size: compact ? 10 : 12, weight: .heavy, design: .monospaced))
                .foregroundStyle(balanceColor)
                .lineLimit(1)
            if row.shieldActive == true {
                Text("🛡")
                    .font(.system(size: compact ? 9 : 11))
            }
        }
        .padding(compact ? 7 : 9)
        .frame(maxWidth: .infinity, minHeight: compact ? 56 : 92, alignment: .topLeading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                    .fill(NFGTheme.panelGradient)
                if position == 1 {
                    RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                        .fill(NFGTheme.gold.opacity(0.06))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.md, style: .continuous)
                .stroke(position == 1 ? NFGTheme.gold.opacity(0.6) : NFGTheme.border, lineWidth: position == 1 ? 1.2 : 1)
        )
        .shadow(color: position == 1 ? NFGTheme.gold.opacity(0.2) : .clear, radius: 8)
    }

    private var balanceColor: Color {
        if row.balance >= 1_000_000 { return NFGTheme.gold }
        if row.balance >= 100_000 { return NFGTheme.accent2 }
        return NFGTheme.accent
    }
}

struct LeaderboardRowView: View {
    let row: LeaderboardRow
    let position: Int
    let isYou: Bool

    private var positionColor: Color {
        switch position {
        case 1: return NFGTheme.gold
        case 2: return NFGTheme.accent
        case 3: return NFGTheme.accent2
        default: return NFGTheme.muted
        }
    }

    var body: some View {
        HStack(spacing: NFGSpacing.md) {
            Text("\(position)")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(positionColor)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(positionColor.opacity(position <= 3 ? 0.18 : 0.08))
                )
                .overlay(Circle().stroke(positionColor.opacity(position <= 3 ? 0.5 : 0.2), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(row.resolvedDisplayName)
                        .font(.system(size: 14, weight: isYou ? .bold : .semibold, design: .rounded))
                        .foregroundStyle(NFGTheme.text)
                        .lineLimit(1)
                    if row.shieldActive == true {
                        Text("🛡")
                            .font(.system(size: 11))
                    }
                    if row.superFan == true {
                        Text("★")
                            .font(.system(size: 10))
                            .foregroundStyle(NFGTheme.gold)
                    }
                    if isYou {
                        Text("YOU")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(NFGTheme.accent.opacity(0.22)))
                            .overlay(Capsule().stroke(NFGTheme.accent.opacity(0.5)))
                            .foregroundStyle(NFGTheme.accent)
                    }
                }
                Text("@\(row.resolvedUser) · \(row.rank ?? "Rookie") · Lv \(row.level ?? 1)")
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(row.balance.formatted())
                .font(NFGFont.numeric(14, weight: .heavy))
                .foregroundStyle(NFGTheme.accent2)
        }
        .padding(.vertical, NFGSpacing.sm + 2)
        .padding(.horizontal, NFGSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: NFGRadius.md)
                .fill(isYou ? NFGTheme.accent.opacity(0.06) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NFGRadius.md)
                .stroke(isYou ? NFGTheme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
