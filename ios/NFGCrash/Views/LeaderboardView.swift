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
                Text("Top 5")
                    .font(.system(size: compact ? 11 : 13, weight: .bold))
                    .foregroundStyle(NFGTheme.text)
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(NFGTheme.panel.opacity(0.35))
                            .frame(height: compact ? 52 : 88)
                            .frame(maxWidth: .infinity)
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

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            HStack {
                Text("#\(position)")
                    .font(.system(size: compact ? 9 : 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(NFGTheme.muted)
                Spacer()
                if row.superFan == true {
                    Text("★")
                        .font(.system(size: compact ? 8 : 10))
                        .foregroundStyle(NFGTheme.gold)
                }
            }
            Text(row.resolvedDisplayName)
                .font(.system(size: compact ? 9 : 11, weight: .semibold))
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
                .font(.system(size: compact ? 9 : 11, weight: .bold, design: .monospaced))
                .foregroundStyle(balanceColor)
                .lineLimit(1)
            if row.shieldActive == true {
                Text("🛡")
                    .font(.system(size: compact ? 8 : 10))
            }
        }
        .padding(compact ? 6 : 8)
        .frame(maxWidth: .infinity, minHeight: compact ? 52 : 88, alignment: .topLeading)
        .background(NFGTheme.panel.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(position == 1 ? NFGTheme.gold.opacity(0.5) : NFGTheme.border))
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

    var body: some View {
        HStack(spacing: 10) {
            Text("\(position)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(NFGTheme.muted)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(row.resolvedDisplayName)
                        .font(.system(size: 14, weight: isYou ? .bold : .semibold))
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
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(NFGTheme.accent.opacity(0.25))
                            .clipShape(Capsule())
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
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(NFGTheme.accent2)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(isYou ? NFGTheme.panel.opacity(0.65) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
