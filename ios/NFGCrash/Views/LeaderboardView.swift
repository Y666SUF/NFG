import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var sync: SyncClient
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRow: LeaderboardRow?

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
                                TopProfilesStrip(
                                    rows: sync.topBalances,
                                    compact: false,
                                    onRowTap: { selectedRow = $0 }
                                )
                                .padding(.bottom, 12)

                                Text(leaderboardListTitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(NFGTheme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, 8)

                                ForEach(Array(sync.fullBalances.enumerated()), id: \.element.id) { index, row in
                                    LeaderboardRowView(row: row, position: index + 1, isYou: isCurrentUser(row))
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedRow = row }
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
            .sheet(item: $selectedRow) { row in
                LeaderboardPlayerDetailSheet(
                    row: row,
                    isYou: isCurrentUser(row),
                    position: row.rankPosition ?? sync.fullBalances.firstIndex(where: { $0.id == row.id }).map { $0 + 1 }
                )
                .environmentObject(sync)
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

// MARK: - Live shield countdown

struct ShieldTimerBadge: View {
    let row: LeaderboardRow
    var compact: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let msLeft = row.shieldMsRemaining(at: context.date)
            if msLeft > 0 {
                HStack(spacing: compact ? 2 : 4) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: compact ? 8 : 10, weight: .bold))
                    Text(LeaderboardRow.formatDurationMs(msLeft))
                        .font(.system(size: compact ? 9 : 11, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(NFGTheme.accent)
                .padding(.horizontal, compact ? 5 : 8)
                .padding(.vertical, compact ? 2 : 4)
                .background(NFGTheme.accent.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(NFGTheme.accent.opacity(0.35)))
            }
        }
    }
}

struct LeaderboardPlayerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sync: SyncClient
    let row: LeaderboardRow
    let isYou: Bool
    let position: Int?

    @State private var lookup: PlayerLookupResponse?
    @State private var isLoadingLookup = false
    @State private var lookupError: String?
    @State private var showStealConfirm = false
    @State private var isStealing = false

    private var stealChargesAvailable: Int {
        sync.wallet.inventory.stealCharges
    }

    private var canStealThisPlayer: Bool {
        !isYou && stealChargesAvailable > 0 && row.balance > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if let position {
                                Text("#\(position)")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(NFGTheme.gold)
                            }
                            PlayerDisplayNameRow(
                                name: row.resolvedDisplayName,
                                styleId: row.nameStyle ?? "none",
                                badgeId: row.nameBadge ?? "none",
                                nameFont: .system(size: 22, weight: .bold, design: .rounded),
                                compactBadge: false
                            ) {
                                HStack(spacing: 6) {
                                    SuperFanBadgeView(badge: row.superFanBadge, compact: false)
                                    if isYou {
                                        Text("YOU")
                                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                                            .tracking(0.8)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(NFGTheme.accent.opacity(0.22)))
                                            .foregroundStyle(NFGTheme.accent)
                                    }
                                }
                            }
                        }
                        Text("@\(row.resolvedUser)")
                            .font(.system(size: 13))
                            .foregroundStyle(NFGTheme.muted)
                        Text("\(row.rank ?? "Rookie") · Level \(row.level ?? 1)")
                            .font(.system(size: 12))
                            .foregroundStyle(NFGTheme.muted)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("BALANCE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(NFGTheme.muted)
                        Text("\(row.balance.formatted()) pts")
                            .font(.system(size: 28, weight: .heavy, design: .monospaced))
                            .foregroundStyle(NFGTheme.accent2)
                        if let allTime = row.allTime {
                            Text("All-time: \(allTime.formatted()) pts")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(NFGTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(NFGTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))

                    if canStealThisPlayer {
                        stealActionCard
                    }

                    bettingStatsCard
                    powerupsStatusCard
                    shieldStatusCard
                    jetLockStatusCard

                    MobileGameHostAdminPanel(
                        userId: row.resolvedUser,
                        seed: AdminPlayerSeed.from(row: row, lookup: lookup)
                    ) {
                        Task { await sync.refreshLeaderboard() }
                    }
                }
                .padding(20)
            }
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle("Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(NFGTheme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
        .task(id: row.resolvedUser) {
            await loadPlayerLookup()
        }
        .alert("Steal points?", isPresented: $showStealConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Steal", role: .destructive) {
                Task { await performSteal() }
            }
        } message: {
            Text("Use 1 steal charge to take all of \(row.resolvedDisplayName)'s \(row.balance.formatted()) pts.")
        }
    }

    @ViewBuilder
    private var stealActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Steal powerup", systemImage: "bolt.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(NFGTheme.gold)

            Text("Transfer this player's entire balance to you. Shields block steals.")
                .font(.system(size: 12))
                .foregroundStyle(NFGTheme.muted)

            Button {
                showStealConfirm = true
            } label: {
                HStack(spacing: 8) {
                    if isStealing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("STEAL \(row.balance.formatted()) PTS")
                            .tracking(0.8)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(NFGPrimaryButtonStyle(isDisabled: isStealing))
            .disabled(isStealing)

            Text("\(stealChargesAvailable) steal charge\(stealChargesAvailable == 1 ? "" : "s") left")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.gold.opacity(0.35)))
    }

    private func performSteal() async {
        isStealing = true
        defer { isStealing = false }
        await sync.stealFrom(target: row.resolvedUser)
        await sync.refreshLeaderboard()
        await sync.refreshWallet(force: true)
        await loadPlayerLookup()
    }

    @ViewBuilder
    private var bettingStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Betting stats", systemImage: "chart.bar.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(NFGTheme.accent2)

            if isLoadingLookup && lookup == nil {
                HStack(spacing: 8) {
                    ProgressView().tint(NFGTheme.accent)
                    Text("Loading stats…")
                        .font(.system(size: 12))
                        .foregroundStyle(NFGTheme.muted)
                }
            } else if let lookupError, lookup == nil {
                Text(lookupError)
                    .font(.system(size: 12))
                    .foregroundStyle(NFGTheme.muted)
            } else {
                HStack(spacing: 12) {
                    statTile(title: "Total bet", value: lookup?.resolvedTotalBet ?? 0, tint: NFGTheme.accent2)
                    statTile(title: "Highest bet", value: lookup?.highestBet ?? 0, tint: NFGTheme.gold)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func statTile(title: String, value: Int, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            Text("\(value.formatted()) pts")
                .font(.system(size: 16, weight: .heavy, design: .monospaced))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadPlayerLookup() async {
        isLoadingLookup = true
        lookupError = nil
        defer { isLoadingLookup = false }
        guard let api = try? GameAPI(baseURLString: PlayerSession.serverBaseURL) else {
            lookupError = "Could not connect to server."
            return
        }
        do {
            lookup = try await api.fetchPlayerLookup(user: row.resolvedUser)
        } catch {
            lookupError = error.localizedDescription
        }
    }

    @ViewBuilder
    private var powerupsStatusCard: some View {
        let inv = lookup?.inventory
        VStack(alignment: .leading, spacing: 12) {
            Label("Powerups", systemImage: "bolt.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(NFGTheme.accent2)
            if isLoadingLookup && inv == nil {
                ProgressView().tint(NFGTheme.accent2)
            } else {
                HStack(spacing: 10) {
                    powerupTile(title: "Steals", value: inv?.stealCharges ?? 0, icon: "bolt.fill")
                    powerupTile(title: "Shield breaks", value: inv?.shieldBreakCharges ?? 0, icon: "hammer.fill")
                    powerupTile(title: "Jet locks", value: inv?.jetLockCharges ?? 0, icon: "snowflake")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func powerupTile(title: String, value: Int, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NFGTheme.gold)
            Text("\(value)")
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(NFGTheme.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var jetLockStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Jet lock status", systemImage: "airplane")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(NFGTheme.accent2)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let jetMs = jetLockMsRemaining(at: context.date)
                if jetMs > 0 {
                    HStack(spacing: 10) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(NFGTheme.accent2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Jet locked")
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(LeaderboardRow.formatDurationMs(jetMs)) remaining")
                                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                .foregroundStyle(NFGTheme.accent2)
                        }
                    }
                    Text("Player cannot bet or use chat commands while jet locked.")
                        .font(.system(size: 12))
                        .foregroundStyle(NFGTheme.muted)
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "airplane")
                            .font(.system(size: 24))
                            .foregroundStyle(NFGTheme.muted)
                        Text("Not jet locked")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NFGTheme.text)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NFGTheme.border))
    }

    private func jetLockMsRemaining(at date: Date) -> Int {
        if let until = lookup?.jetLockUntil, until > 0 {
            return max(0, until - Int(date.timeIntervalSince1970 * 1000))
        }
        if let ms = lookup?.jetLockMsLeft, ms > 0 { return ms }
        if lookup?.jetLockActive == true {
            return max(0, (lookup?.jetLockSecondsLeft ?? 0) * 1000)
        }
        return 0
    }

    @ViewBuilder
    private var shieldStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Shield status", systemImage: "shield.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(NFGTheme.accent)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let msLeft = row.shieldMsRemaining(at: context.date)
                if msLeft > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 28))
                                .foregroundStyle(NFGTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Shield active")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(NFGTheme.text)
                                Text("\(LeaderboardRow.formatDurationMs(msLeft)) remaining")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(NFGTheme.accent)
                            }
                        }
                        Text("Steals and shield breaks are blocked until this timer expires.")
                            .font(.system(size: 12))
                            .foregroundStyle(NFGTheme.muted)
                    }
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.slash")
                            .font(.system(size: 24))
                            .foregroundStyle(NFGTheme.muted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No active shield")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(NFGTheme.text)
                            Text("This player can be targeted with steal or break-shield powerups.")
                                .font(.system(size: 12))
                                .foregroundStyle(NFGTheme.muted)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(row.hasActiveShield() ? NFGTheme.accent.opacity(0.4) : NFGTheme.border)
        )
    }
}

struct TopProfilesStrip: View {
    let rows: [LeaderboardRow]
    var compact: Bool = true
    var onTap: (() -> Void)?
    var onRowTap: ((LeaderboardRow) -> Void)?

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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let onRowTap {
                                    onRowTap(rows[index])
                                } else {
                                    onTap?()
                                }
                            }
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
            if onRowTap == nil {
                onTap?()
            }
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
                VaultBadgeIcon(badgeId: row.nameBadge ?? "none", size: compact ? 12 : 14)
                Text("#\(position)")
                    .font(.system(size: compact ? 9 : 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(positionTint)
                Spacer()
                SuperFanBadgeView(badge: row.superFanBadge, compact: true)
            }
            NameStyledText(
                name: row.resolvedDisplayName,
                styleId: row.nameStyle ?? "none",
                font: .system(size: compact ? 10 : 12, weight: .bold, design: .rounded)
            )
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
                PlayerDisplayNameRow(
                    name: row.resolvedDisplayName,
                    styleId: row.nameStyle ?? "none",
                    badgeId: row.nameBadge ?? "none",
                    nameFont: .system(size: 14, weight: isYou ? .bold : .semibold, design: .rounded),
                    compactBadge: true
                ) {
                    HStack(spacing: 6) {
                        SuperFanBadgeView(badge: row.superFanBadge, compact: true)
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
                }
                HStack(spacing: 6) {
                    Text("@\(row.resolvedUser) · \(row.rank ?? "Rookie") · Lv \(row.level ?? 1)")
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.muted)
                        .lineLimit(1)
                    ShieldTimerBadge(row: row, compact: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(row.balance.formatted())
                    .font(NFGFont.numeric(14, weight: .heavy))
                    .foregroundStyle(NFGTheme.accent2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(NFGTheme.muted.opacity(0.6))
            }
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
