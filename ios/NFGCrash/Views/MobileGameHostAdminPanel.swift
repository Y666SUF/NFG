import SwiftUI

/// Host-only player editor — talks to `/api/mobile/admin/*` on the game server.
struct MobileGameHostAdminPanel: View {
    let userId: String
    var seed: AdminPlayerSeed
    var onSaved: (() -> Void)?

    @State private var wallet: PlayerWallet?
    @State private var baseline: AdminPlayerSeed
    @State private var balanceText = ""
    @State private var allTimeText = ""
    @State private var stealText = ""
    @State private var breakText = ""
    @State private var jetText = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var statusMessage = ""
    @State private var errorMessage = ""
    @State private var showWipeConfirm = false
    @State private var didPrefill = false

    init(userId: String, seed: AdminPlayerSeed, onSaved: (() -> Void)? = nil) {
        self.userId = userId
        self.seed = seed
        self.onSaved = onSaved
        _baseline = State(initialValue: seed)
    }

    private var isHost: Bool { ChatOwnerConfig.isOwnerLinkedAccount() }

    var body: some View {
        Group {
            if isHost {
                hostPanel
            }
        }
    }

    private var hostPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Host controls", systemImage: "wrench.and.screwdriver.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(NFGTheme.gold)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().tint(NFGTheme.gold)
                    Text("Refreshing from server…")
                        .font(.system(size: 11))
                        .foregroundStyle(NFGTheme.muted)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(NFGTheme.danger)
            }

            statusTimersRow
            editableFields
            quickActions
            saveRow

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(NFGTheme.accent2)
            }
        }
        .padding(16)
        .background(NFGTheme.panel2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(NFGTheme.gold.opacity(0.35), lineWidth: 1)
        )
        .onAppear {
            applyPrefill(from: seed, updateBaseline: true)
        }
        .onChange(of: seed) { _, newSeed in
            // Enrich fields when lookup finishes — only if server wallet not loaded yet.
            if wallet == nil {
                applyPrefill(from: newSeed, updateBaseline: true)
            }
        }
        .task(id: userId) {
            await loadPlayer()
        }
        .confirmationDialog(
            "Remove @\(userId) from the leaderboard?",
            isPresented: $showWipeConfirm,
            titleVisibility: .visible
        ) {
            Button("Wipe balance & scores", role: .destructive) {
                Task { await wipePlayer() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Zeros their balance and all-time on the server. Jet lock is cleared.")
        }
    }

    private var statusTimersRow: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let shieldMs = wallet?.shieldMsRemaining(at: context.date) ?? 0
            let jetMs = wallet?.jetLockMsRemaining(at: context.date) ?? 0
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    statusChip(
                        icon: "shield.fill",
                        label: "Shield",
                        value: shieldMs > 0 ? LeaderboardRow.formatDurationMs(shieldMs) : "Off",
                        active: shieldMs > 0,
                        tint: NFGTheme.accent
                    )
                    statusChip(
                        icon: "airplane",
                        label: "Jet lock",
                        value: jetMs > 0 ? LeaderboardRow.formatDurationMs(jetMs) : "Off",
                        active: jetMs > 0,
                        tint: NFGTheme.accent2
                    )
                }
                HStack(spacing: 8) {
                    inventoryChip(title: "Steals", count: parsedInt(stealText) ?? baseline.stealCharges, icon: "bolt.fill")
                    inventoryChip(title: "Breaks", count: parsedInt(breakText) ?? baseline.shieldBreakCharges, icon: "hammer.fill")
                    inventoryChip(title: "Jets", count: parsedInt(jetText) ?? baseline.jetLockCharges, icon: "snowflake")
                }
            }
        }
    }

    private var editableFields: some View {
        VStack(spacing: 10) {
            adminField(title: "Balance (pts)", text: $balanceText, keyboard: .numberPad)
            adminField(title: "All-time (pts)", text: $allTimeText, keyboard: .numberPad)
            HStack(spacing: 10) {
                adminField(title: "Steal charges", text: $stealText, keyboard: .numberPad)
                adminField(title: "Shield breaks", text: $breakText, keyboard: .numberPad)
            }
            adminField(title: "Jet lock charges", text: $jetText, keyboard: .numberPad)
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick actions")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            HStack(spacing: 8) {
                quickButton("+48h Shield", icon: "shield.lefthalf.filled") {
                    Task { await quickShieldGrant() }
                }
                quickButton("Clear shield", icon: "shield.slash") {
                    Task { await quickShieldClear() }
                }
            }
            HStack(spacing: 8) {
                quickButton("Jet lock 1h", icon: "airplane.circle") {
                    Task { await quickJetGrant(minutes: 60) }
                }
                quickButton("Clear jet", icon: "airplane.departure") {
                    Task { await quickJetClear() }
                }
            }
            Button(role: .destructive) {
                showWipeConfirm = true
            } label: {
                Label("Wipe from leaderboard", systemImage: "trash")
                    .font(.system(size: 11, weight: .semibold))
            }
            .disabled(isSaving)
        }
    }

    private var saveRow: some View {
        Button {
            Task { await saveChanges() }
        } label: {
            HStack {
                if isSaving {
                    ProgressView().tint(.black)
                }
                Text(isSaving ? "Saving…" : "Save changes to server")
                    .font(.system(size: 13, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(NFGTheme.gold)
            .foregroundStyle(.black.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(isSaving)
    }

    private func adminField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NFGTheme.muted)
            TextField(title, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .padding(10)
                .background(NFGTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(NFGTheme.border))
        }
    }

    private func statusChip(icon: String, label: String, value: String, active: Bool, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(NFGTheme.muted)
                Text(value)
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
            }
        }
        .foregroundStyle(active ? tint : NFGTheme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(active ? tint.opacity(0.12) : NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func inventoryChip(title: String, count: Int, icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text("\(count)")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
            Text(title)
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(NFGTheme.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func quickButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(NFGTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(NFGTheme.border))
        }
        .buttonStyle(.plain)
        .foregroundStyle(NFGTheme.text)
        .disabled(isSaving)
    }

    private func applyPrefill(from seed: AdminPlayerSeed, updateBaseline: Bool) {
        balanceText = String(seed.balance)
        allTimeText = String(seed.allTime)
        stealText = String(seed.stealCharges)
        breakText = String(seed.shieldBreakCharges)
        jetText = String(seed.jetLockCharges)
        if updateBaseline {
            baseline = seed
        }
        didPrefill = true
    }

    @MainActor
    private func loadPlayer() async {
        guard isHost else { return }
        if !didPrefill {
            applyPrefill(from: seed, updateBaseline: true)
        }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        guard let api = try? GameAPI(baseURLString: PlayerSession.serverBaseURL) else {
            errorMessage = "Using leaderboard values — could not connect for a live refresh."
            return
        }

        do {
            let loaded = try await api.fetchAdminPlayer(userId: userId)
            applyWallet(loaded)
            errorMessage = ""
            return
        } catch {
            // Fall back to public lookup so fields still match server data.
            do {
                let lookup = try await api.fetchPlayerLookup(user: userId)
                let fromLookup = AdminPlayerSeed(
                    balance: lookup.balance ?? seed.balance,
                    allTime: lookup.allTime ?? seed.allTime,
                    stealCharges: lookup.inventory?.stealCharges ?? seed.stealCharges,
                    shieldBreakCharges: lookup.inventory?.shieldBreakCharges ?? seed.shieldBreakCharges,
                    jetLockCharges: lookup.inventory?.jetLockCharges ?? seed.jetLockCharges
                )
                applyPrefill(from: fromLookup, updateBaseline: true)
                errorMessage = "Admin refresh unavailable — showing live lookup data. Edits still save if host API works."
            } catch {
                errorMessage = "Showing leaderboard values. \(error.localizedDescription)"
            }
        }
    }

    private func applyWallet(_ w: PlayerWallet) {
        wallet = w
        let merged = AdminPlayerSeed(
            balance: w.balance,
            allTime: w.allTime,
            stealCharges: w.inventory.stealCharges,
            shieldBreakCharges: w.inventory.shieldBreakCharges,
            jetLockCharges: w.inventory.jetLockCharges
        )
        applyPrefill(from: merged, updateBaseline: true)
    }

    private func baselineBalance() -> Int { wallet?.balance ?? baseline.balance }
    private func baselineAllTime() -> Int { wallet?.allTime ?? baseline.allTime }
    private func baselineSteals() -> Int { wallet?.inventory.stealCharges ?? baseline.stealCharges }
    private func baselineBreaks() -> Int { wallet?.inventory.shieldBreakCharges ?? baseline.shieldBreakCharges }
    private func baselineJets() -> Int { wallet?.inventory.jetLockCharges ?? baseline.jetLockCharges }

    @MainActor
    private func saveChanges() async {
        guard isHost, let api = try? GameAPI(baseURLString: PlayerSession.serverBaseURL) else { return }
        isSaving = true
        statusMessage = ""
        defer { isSaving = false }

        var body = AdminPlayerUpdateBody(userId: userId)
        var touched = false
        if let b = parsedInt(balanceText), b != baselineBalance() {
            body.balance = b
            touched = true
        }
        if let a = parsedInt(allTimeText), a != baselineAllTime() {
            body.allTime = a
            touched = true
        }
        if let s = parsedInt(stealText), s != baselineSteals() {
            body.stealCharges = s
            touched = true
        }
        if let s = parsedInt(breakText), s != baselineBreaks() {
            body.shieldBreakCharges = s
            touched = true
        }
        if let j = parsedInt(jetText), j != baselineJets() {
            body.jetLockCharges = j
            touched = true
        }
        guard touched else {
            statusMessage = "No changes to save."
            return
        }

        do {
            let updated = try await api.updateAdminPlayer(body)
            applyWallet(updated)
            statusMessage = "Saved — \(updated.changes?.joined(separator: ", ") ?? "updated")."
            errorMessage = ""
            onSaved?()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func quickShieldGrant() async {
        await runQuickUpdate(
            AdminPlayerUpdateBody(userId: userId, shieldAction: "grant", shieldHours: 48)
        )
    }

    @MainActor
    private func quickShieldClear() async {
        await runQuickUpdate(AdminPlayerUpdateBody(userId: userId, shieldAction: "clear"))
    }

    @MainActor
    private func quickJetGrant(minutes: Int) async {
        await runQuickUpdate(
            AdminPlayerUpdateBody(userId: userId, jetLockAction: "grant", jetLockMinutes: minutes)
        )
    }

    @MainActor
    private func quickJetClear() async {
        await runQuickUpdate(AdminPlayerUpdateBody(userId: userId, jetLockAction: "clear"))
    }

    @MainActor
    private func runQuickUpdate(_ body: AdminPlayerUpdateBody) async {
        guard isHost, let api = try? GameAPI(baseURLString: PlayerSession.serverBaseURL) else { return }
        isSaving = true
        statusMessage = ""
        defer { isSaving = false }
        do {
            let updated = try await api.updateAdminPlayer(body)
            applyWallet(updated)
            statusMessage = "Updated — \(updated.changes?.joined(separator: ", ") ?? "ok")."
            errorMessage = ""
            onSaved?()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func wipePlayer() async {
        guard isHost, let api = try? GameAPI(baseURLString: PlayerSession.serverBaseURL) else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await api.wipeAdminPlayer(userId: userId)
            statusMessage = "Player wiped from leaderboard."
            await loadPlayer()
            onSaved?()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func parsedInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed.replacingOccurrences(of: ",", with: ""))
    }
}
