import SwiftUI

enum JumpPlayMode: String, CaseIterable, Identifiable {
    case solo = "Solo"
    case vs = "VS"

    var id: String { rawValue }
}

struct SnakeJumpGameView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var canvas = SnakeJumpCanvasController()
    @State private var api: GameAPI?
    @State private var playStatus: ArcadePlayResponse?
    @State private var sessionPoints = 0
    @State private var bestHeight = 0
    @State private var rewardPreview = SnakeJumpEngine.milestoneReward
    @State private var balance = 0
    @State private var shopItems: [JumpShopItem] = JumpShopCatalog.fallback
    @State private var equippedSkin = "classic"
    @State private var ownedSkins: [String] = ["classic"]
    @State private var skinFill = "#596ff2"
    @State private var skinRing = "#f2c733"
    @State private var message = ""
    @State private var playMode: JumpPlayMode = .solo
    @State private var vsClient: JumpVSClient?
    @State private var vsSnapshot: JumpVsSnapshot?
    @State private var vsMatchSeed: Int?
    @State private var vsMatchId: String?
    @State private var showShop = false
    @State private var shopMessage = ""
    @State private var isLoading = true
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            modePicker
            hudRow
            SnakeJumpCanvasHost(controller: canvas)
                .frame(maxWidth: .infinity)
                .frame(height: min(420, UIScreen.main.bounds.width * 1.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)

            if playMode == .vs {
                vsLobbyPanel
            }

            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(NFGTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
            }

            controlsRow
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 5 / 255, green: 8 / 255, blue: 16 / 255),
                    NFGTheme.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("NFG Jump")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showShop = true
                } label: {
                    Label("Shop", systemImage: "bag.fill")
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShop) {
            jumpShopSheet
        }
        .task {
            await bootstrap()
        }
        .onDisappear {
            vsClient?.disconnect()
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $playMode) {
            ForEach(JumpPlayMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onChange(of: playMode) { _, mode in
            if mode == .solo {
                leaveVs()
            } else if vsClient == nil {
                joinVs()
            }
        }
    }

    private var hudRow: some View {
        HStack(spacing: 10) {
            Text("\(canvas.engine.currentHeight)m")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(SnakeJumpTheme.swiftColor(hex: skinFill, fallback: NFGTheme.accent))
            Text("Best \(bestHeight)m")
            Text("Session \(sessionPoints.formatted()) pts")
            Text("+\(rewardPreview) @ \(canvas.engine.nextMilestoneHeight)m")
                .foregroundStyle(NFGTheme.gold)
            if playMode == .vs, let vsSnapshot {
                Text("VS \(vsSnapshot.opponents.count)")
                    .foregroundStyle(NFGTheme.accent2)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(NFGTheme.muted)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var vsLobbyPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Jump VS")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(vsPhaseLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NFGTheme.accent)
            }
            Text(vsHelpText)
                .font(.system(size: 11))
                .foregroundStyle(NFGTheme.muted)
            if let players = vsSnapshot?.players, !players.isEmpty {
                ForEach(players) { player in
                    HStack {
                        Text(player.displayName ?? player.id)
                        Spacer()
                        Text("\(player.height ?? 0)m")
                            .monospacedDigit()
                    }
                    .font(.system(size: 12))
                }
            } else {
                Text("Waiting for players…")
                    .font(.system(size: 12))
                    .foregroundStyle(NFGTheme.muted)
            }
            HStack {
                if vsClient == nil {
                    Button("Join VS lobby") {
                        joinVs()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(NFGTheme.accent)
                } else {
                    Button("Leave lobby") {
                        leaveVs()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(12)
        .background(NFGTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var controlsRow: some View {
        HStack(spacing: 16) {
            holdButton(label: "◀", active: $canvas.moveLeft)
            Button {
                Task { await startRun() }
            } label: {
                Text("New Run")
                    .font(.system(size: 15, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(SnakeJumpTheme.swiftColor(hex: skinFill, fallback: NFGTheme.accent))
            holdButton(label: "▶", active: $canvas.moveRight)
        }
        .padding(16)
    }

    private func holdButton(label: String, active: Binding<Bool>) -> some View {
        Text(label)
            .font(.system(size: 22, weight: .bold))
            .frame(width: 64, height: 52)
            .background(NFGTheme.panel2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NFGTheme.border))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in active.wrappedValue = true }
                    .onEnded { _ in active.wrappedValue = false }
            )
    }

    private var jumpShopSheet: some View {
        NavigationStack {
            List {
                Section {
                    Text("Balance: \(balance.formatted()) pts")
                        .foregroundStyle(NFGTheme.muted)
                    if !shopMessage.isEmpty {
                        Text(shopMessage)
                            .foregroundStyle(NFGTheme.accent2)
                    }
                }
                Section("Circle Shop") {
                    ForEach(shopItems) { item in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(SnakeJumpTheme.swiftColor(hex: item.fill, fallback: NFGTheme.accent))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle().stroke(SnakeJumpTheme.swiftColor(hex: item.ring, fallback: NFGTheme.gold), lineWidth: 2)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name ?? item.id)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(item.desc ?? "")
                                    .font(.system(size: 11))
                                    .foregroundStyle(NFGTheme.muted)
                            }
                            Spacer()
                            if item.equipped == true {
                                Text("Equipped")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(NFGTheme.accent2)
                            } else if item.owned == true {
                                Button("Equip") {
                                    Task { await equipSkin(item.id) }
                                }
                                .font(.system(size: 12, weight: .semibold))
                            } else {
                                let cost = item.cost ?? 0
                                Button(cost == 0 ? "Free" : "Buy \(cost.formatted())") {
                                    Task { await buySkin(item.id) }
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .disabled(balance < cost)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NFGTheme.background.ignoresSafeArea())
            .navigationTitle("Circle Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showShop = false }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var vsPhaseLabel: String {
        guard let vsSnapshot else { return "Lobby" }
        switch vsSnapshot.phase {
        case "countdown": return "Starting in \(vsSnapshot.countdownSeconds)s"
        case "match": return vsSnapshot.eliminated ? "Eliminated" : "Match live"
        case "results": return "Results"
        default: return "Lobby"
        }
    }

    private var vsHelpText: String {
        guard let vsSnapshot else {
            return "2+ players start a 15s countdown. Winner takes the combined pot."
        }
        switch vsSnapshot.phase {
        case "countdown":
            return "\(vsSnapshot.players.count) players — match starts in \(vsSnapshot.countdownSeconds)s"
        case "match":
            return "Stay within one milestone of the leader or you're eliminated!"
        case "results":
            if let winnerId = vsSnapshot.winnerId {
                return "Winner \(winnerId) takes \(vsSnapshot.pot.formatted()) pts"
            }
            return "Match ended."
        default:
            return "2+ players start a 15s countdown. Winner takes the combined pot."
        }
    }

    @MainActor
    private func bootstrap() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try GameAPI(baseURLString: PlayerSession.serverBaseURL)
            api = client
            wireCanvasCallbacks()
            let status = try await client.arcadePlay(gameId: "nfg_snake_jump", action: "status")
            applyStatus(status)
            if let data = try? await client.fetchProfileAvatar(), let img = UIImage(data: data) {
                canvas.profileImage = img
            }
        } catch {
            loadError = error.localizedDescription
            message = error.localizedDescription
        }
    }

    private func wireCanvasCallbacks() {
        canvas.skinFill = skinFill
        canvas.skinRing = skinRing
        canvas.onMilestone = { await claimMilestone() }
        canvas.onGameOver = { height in await endRun(height: height) }
        canvas.onProgressTick = { height, points in
            vsClient?.reportProgress(height: height, sessionPoints: points)
        }
    }

    @MainActor
    private func applyStatus(_ status: ArcadePlayResponse) {
        playStatus = status
        sessionPoints = status.sessionPoints ?? 0
        bestHeight = status.bestLevel ?? 0
        rewardPreview = status.levelRewardPreview ?? SnakeJumpEngine.milestoneReward
        balance = status.balance ?? balance
        shopItems = JumpShopCatalog.merged(
            serverItems: status.jumpShop,
            equippedId: status.equippedSkin ?? equippedSkin,
            ownedSkins: status.ownedSkins ?? ownedSkins
        )
        equippedSkin = status.equippedSkin ?? equippedSkin
        ownedSkins = status.ownedSkins ?? ownedSkins
        skinFill = status.skinFill ?? skinFill
        skinRing = status.skinRing ?? skinRing
        canvas.skinFill = skinFill
        canvas.skinRing = skinRing
        canvas.sessionPoints = sessionPoints
        canvas.engine.milestonesClaimed = status.sessionMilestones ?? 0
    }

    @MainActor
    private func startRun() async {
        guard let api else { return }
        do {
            var payload: [String: Any] = [:]
            if playMode == .vs, let vsMatchId {
                payload["vsMatchId"] = vsMatchId
            }
            let res = try await api.arcadePlay(gameId: "nfg_snake_jump", action: "start", payload: payload)
            applyStatus(res)
            message = res.message ?? "Climb!"
            let width = max(UIScreen.main.bounds.width - 24, 280)
            if playMode == .vs, let vsMatchSeed {
                canvas.resetEngine(viewWidth: width, matchSeed: vsMatchSeed)
            } else {
                canvas.resetEngine(viewWidth: width)
            }
            canvas.engine.milestonesClaimed = res.sessionMilestones ?? 0
            canvas.sessionActive = true
            canvas.running = true
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func claimMilestone() async {
        guard let api else { return }
        let height = canvas.engine.currentHeight
        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_snake_jump",
                action: "milestone",
                payload: ["height": height]
            )
            applyStatus(res)
            canvas.engine.milestonesClaimed = res.sessionMilestones ?? canvas.engine.milestonesClaimed + 1
            message = res.message ?? "Milestone!"
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func endRun(height: Int) async {
        guard let api else { return }
        if playMode == .vs {
            vsClient?.sendForfeit()
        }
        do {
            let res = try await api.arcadePlay(
                gameId: "nfg_snake_jump",
                action: "game_over",
                payload: ["height": height]
            )
            applyStatus(res)
            message = res.message ?? "Run over at \(height)m"
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    private func buySkin(_ itemId: String) async {
        guard let api else { return }
        do {
            let res = try await api.arcadePlay(gameId: "nfg_snake_jump", action: "buy", payload: ["itemId": itemId])
            applyStatus(res)
            shopMessage = res.message ?? "Purchased!"
            vsClient?.updateHooks(makeVsHooks())
        } catch {
            shopMessage = error.localizedDescription
        }
    }

    @MainActor
    private func equipSkin(_ itemId: String) async {
        guard let api else { return }
        do {
            let res = try await api.arcadePlay(gameId: "nfg_snake_jump", action: "equip", payload: ["itemId": itemId])
            applyStatus(res)
            shopMessage = res.message ?? "Equipped!"
            vsClient?.updateHooks(makeVsHooks())
        } catch {
            shopMessage = error.localizedDescription
        }
    }

    private func makeVsHooks() -> JumpVSClient.Hooks {
        var hooks = JumpVSClient.Hooks()
        hooks.skinId = equippedSkin
        hooks.fill = skinFill
        hooks.ring = skinRing
        hooks.onLobbyState = { state in
            Task { @MainActor in
                vsSnapshot = state
            }
        }
        hooks.onMatchStart = { state in
            Task { @MainActor in
                vsSnapshot = state
                vsMatchSeed = state.matchSeed
                vsMatchId = state.matchId
                canvas.ghostOpponents = JumpVSClient.ghostOpponents(from: state.opponents)
            }
        }
        hooks.onOpponents = { opponents in
            Task { @MainActor in
                canvas.ghostOpponents = JumpVSClient.ghostOpponents(from: opponents)
            }
        }
        hooks.onEliminated = { reason in
            Task { @MainActor in
                message = "Eliminated — \(reason)"
                canvas.running = false
                canvas.sessionActive = false
            }
        }
        hooks.onMatchEnd = { msg in
            Task { @MainActor in
                vsMatchSeed = nil
                vsMatchId = nil
                vsSnapshot = JumpVsSnapshot(
                    phase: "results",
                    players: vsSnapshot?.players ?? [],
                    countdownSeconds: 0,
                    matchSeed: nil,
                    matchId: nil,
                    eliminated: false,
                    opponents: [],
                    pot: msg["pot"] as? Int ?? 0,
                    winnerId: msg["winnerId"] as? String
                )
            }
        }
        hooks.onError = { err in
            Task { @MainActor in message = err }
        }
        return hooks
    }

    private func joinVs() {
        guard let api else { return }
        let client = JumpVSClient(api: api, hooks: makeVsHooks())
        vsClient = client
        do {
            try client.connect()
            message = "Connecting to Jump VS…"
        } catch {
            message = error.localizedDescription
            vsClient = nil
        }
    }

    private func leaveVs() {
        vsClient?.disconnect()
        vsClient = nil
        vsSnapshot = nil
        vsMatchSeed = nil
        vsMatchId = nil
        canvas.ghostOpponents = []
    }
}
