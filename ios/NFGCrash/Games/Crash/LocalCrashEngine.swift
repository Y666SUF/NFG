import Foundation

/// On-device crash rounds — same math as `server/game.js` / `server/crash.js`.
/// Does not need the live server; SyncClient syncs balance deltas when online.
@MainActor
final class LocalCrashEngine: ObservableObject {
    struct Config {
        var bettingSeconds: Int = 15
        var tickMs: Int = 50
        var multiplierPerSecond: Double = 0.42
        var minRunBeforeCrashMs: Int = 1400
        var minBet: Int = 1
        var minCashout: Double = 1.05
        var maxCashout: Double = 500
        var autoRestartMs: Int = 10_000
        var houseEdge: Double = 0.03
        var maxMultiplier: Double = 500
        var profitTaxRate: Double = 0.05
    }

    struct ActiveBet: Equatable {
        var amount: Int
        var cashout: Double
        var displayName: String
        var userId: String
    }

    struct RoundSettlement: Equatable {
        var id: String
        var roundId: Int
        var stake: Int
        var result: String // win | lose | empty
        var settleMult: Double?
        var crashPoint: Double
        var payout: Int
        var tax: Int
        var netDelta: Int
        var userId: String
        var displayName: String
        var createdAt: TimeInterval
    }

    let config: Config

    @Published private(set) var phase: GamePhase = .idle
    @Published private(set) var roundId: Int = 0
    @Published private(set) var multiplier: Double = 1
    @Published private(set) var crashPoint: Double?
    @Published private(set) var bettingEndsAt: Int64 = 0
    @Published private(set) var nextRoundStartsAt: Int64?
    @Published private(set) var runStartedAt: Int64?
    @Published private(set) var activeBet: ActiveBet?
    @Published private(set) var recentCrashes: [Double] = []
    @Published private(set) var lastSettlement: RoundSettlement?
    @Published private(set) var multiplierHistory: [Double] = [1]

    var onStateChanged: (() -> Void)?
    var onNeedBalance: (() -> Int)?
    var onDebit: ((Int) -> Bool)?
    var onCredit: ((Int) -> Void)?
    var onRoundSettled: ((RoundSettlement) -> Void)?

    private var secretCrashPoint: Double = 2
    private var tickTimer: Timer?
    private var phaseTimer: Timer?
    private var isRunningLoop = false

    init(config: Config = Config()) {
        self.config = config
    }

    var opts: CrashGameOpts {
        CrashGameOpts(multiplierPerSecond: config.multiplierPerSecond)
    }

    func makeGameState() -> CrashGameState {
        let open: [OpenBet] = {
            guard let bet = activeBet else { return [] }
            return [OpenBet(user: bet.userId, displayName: bet.displayName, amount: bet.amount, cashout: bet.cashout)]
        }()
        let last: RoundLastResult? = {
            guard let s = lastSettlement else { return nil }
            if s.result == "win" {
                return RoundLastResult(
                    roundId: s.roundId,
                    crashPoint: s.crashPoint,
                    wins: [
                        RoundOutcome(
                            user: s.userId,
                            displayName: s.displayName,
                            result: "win",
                            bet: s.stake,
                            cashout: s.settleMult,
                            payout: s.payout,
                            profit: max(0, s.payout - s.stake)
                        ),
                    ],
                    losses: [],
                    emptyRound: false
                )
            }
            if s.result == "lose" {
                return RoundLastResult(
                    roundId: s.roundId,
                    crashPoint: s.crashPoint,
                    wins: [],
                    losses: [
                        RoundOutcome(
                            user: s.userId,
                            displayName: s.displayName,
                            result: "lose",
                            bet: s.stake,
                            cashout: s.settleMult,
                            payout: 0,
                            profit: -s.stake
                        ),
                    ],
                    emptyRound: false
                )
            }
            return RoundLastResult(
                roundId: s.roundId,
                crashPoint: s.crashPoint,
                wins: [],
                losses: [],
                emptyRound: true
            )
        }()

        return CrashGameState(
            phase: phase,
            roundId: roundId,
            multiplier: multiplier,
            crashPoint: phase == .ended ? (crashPoint ?? secretCrashPoint) : nil,
            bettingEndsAt: bettingEndsAt,
            nextRoundStartsAt: nextRoundStartsAt,
            runStartedAt: runStartedAt,
            opts: opts,
            openBets: phase == .betting || phase == .running ? open : [],
            queuedBets: [],
            taxPot: nil,
            lastResult: last,
            recentCrashes: recentCrashes
        )
    }

    func start() {
        guard !isRunningLoop else { return }
        isRunningLoop = true
        startRound()
    }

    func stop() {
        isRunningLoop = false
        tickTimer?.invalidate()
        tickTimer = nil
        phaseTimer?.invalidate()
        phaseTimer = nil
    }

    @discardableResult
    func placeBet(amount: Int, cashout: Double, userId: String, displayName: String) -> String? {
        guard phase == .betting else {
            return "Wait for the next entry window"
        }
        guard activeBet == nil else {
            return "You already have a bet this round"
        }
        guard amount >= config.minBet else {
            return "Bet too small"
        }
        guard cashout >= config.minCashout, cashout <= config.maxCashout else {
            return "Cashout must be \(String(format: "%.2f", config.minCashout))–\(String(format: "%.0f", config.maxCashout))×"
        }
        let balance = onNeedBalance?() ?? 0
        guard amount <= balance else {
            return "Not enough points"
        }
        guard onDebit?(amount) == true else {
            return "Not enough points"
        }
        activeBet = ActiveBet(
            amount: amount,
            cashout: cashout,
            displayName: displayName,
            userId: userId
        )
        publish()
        return nil
    }

    @discardableResult
    func manualCashout() -> String? {
        guard phase == .running else {
            return "You can only cash out while the round is running"
        }
        guard let bet = activeBet else {
            return "No active bet this round"
        }
        let live = floor(multiplier * 100) / 100
        guard live >= config.minCashout else {
            return "Too early — wait until at least 1.05×"
        }
        settleWin(bet: bet, settleMult: live, manual: true)
        return nil
    }

    // MARK: - Round loop

    private func startRound() {
        guard isRunningLoop else { return }
        tickTimer?.invalidate()
        phaseTimer?.invalidate()

        roundId += 1
        secretCrashPoint = Self.nextCrashMultiplier(
            houseEdge: config.houseEdge,
            maxMultiplier: config.maxMultiplier
        )
        crashPoint = nil
        multiplier = 1
        runStartedAt = nil
        nextRoundStartsAt = nil
        activeBet = nil
        lastSettlement = nil
        multiplierHistory = [1]
        phase = .betting
        bettingEndsAt = Int64(Date().timeIntervalSince1970 * 1000) + Int64(config.bettingSeconds * 1000)
        publish()

        phaseTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.bettingSeconds), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.lockAndRun() }
        }
        if let phaseTimer {
            RunLoop.main.add(phaseTimer, forMode: .common)
        }
    }

    private func lockAndRun() {
        guard isRunningLoop, phase == .betting else { return }
        phase = .running
        multiplier = 1
        runStartedAt = Int64(Date().timeIntervalSince1970 * 1000)
        multiplierHistory = [1]
        publish()
        scheduleTick()
    }

    private func scheduleTick() {
        tickTimer?.invalidate()
        let interval = TimeInterval(config.tickMs) / 1000.0
        tickTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let tickTimer {
            RunLoop.main.add(tickTimer, forMode: .common)
        }
    }

    private func tick() {
        guard isRunningLoop, phase == .running else { return }

        let started = runStartedAt ?? Int64(Date().timeIntervalSince1970 * 1000)
        let elapsedMs = max(0, Int(Date().timeIntervalSince1970 * 1000) - Int(started))
        let crashGraceActive = elapsedMs < config.minRunBeforeCrashMs
        let dt = Double(config.tickMs) / 1000.0

        let highestCashout = activeBet?.cashout ?? 1
        let earlyPace: Double = {
            if multiplier <= 1 { return 0.56 }
            if multiplier >= 5 { return 1 }
            let t = (multiplier - 1) / 4
            return 0.56 + t * 0.44
        }()
        let adaptiveSpeedBoost = min(8, max(1, sqrt(max(1, highestCashout))))
        let postFiveRamp = min(1, max(0, (multiplier - 5) / 8))
        let adaptiveFactor = 1 + (adaptiveSpeedBoost - 1) * postFiveRamp
        let perSecond = config.multiplierPerSecond * earlyPace * adaptiveFactor

        let next = multiplier + perSecond * dt
        let rounded = floor(next * 100) / 100
        let graceCap = crashGraceActive ? max(1, secretCrashPoint - 0.01) : secretCrashPoint
        let settleAt = min(rounded, graceCap)
        multiplier = settleAt

        if multiplierHistory.last.map({ abs($0 - multiplier) > 0.0005 }) ?? true {
            multiplierHistory.append(multiplier)
            if multiplierHistory.count > 240 {
                multiplierHistory.removeFirst(multiplierHistory.count - 240)
            }
        }

        if let bet = activeBet, settleAt >= bet.cashout {
            settleWin(bet: bet, settleMult: bet.cashout, manual: false)
            return
        }

        if !crashGraceActive && rounded >= secretCrashPoint {
            finishRound(resultCrash: secretCrashPoint)
            return
        }

        publish()
    }

    private func settleWin(bet: ActiveBet, settleMult: Double, manual: Bool) {
        let mult = (settleMult * 100).rounded(.down) / 100
        let gross = Int((Double(bet.amount) * mult).rounded(.down))
        let profit = max(0, gross - bet.amount)
        let tax = Int((Double(profit) * config.profitTaxRate).rounded(.down))
        let payout = max(0, gross - tax)
        onCredit?(payout)

        let settlement = RoundSettlement(
            id: UUID().uuidString,
            roundId: roundId,
            stake: bet.amount,
            result: "win",
            settleMult: mult,
            crashPoint: secretCrashPoint,
            payout: payout,
            tax: tax,
            netDelta: payout - bet.amount,
            userId: bet.userId,
            displayName: bet.displayName,
            createdAt: Date().timeIntervalSince1970
        )
        lastSettlement = settlement
        activeBet = nil
        onRoundSettled?(settlement)
        finishRound(resultCrash: secretCrashPoint, alreadySettled: true)
    }

    private func finishRound(resultCrash: Double, alreadySettled: Bool = false) {
        tickTimer?.invalidate()
        tickTimer = nil

        if !alreadySettled, let bet = activeBet {
            // Loss — stake already debited at place.
            let settlement = RoundSettlement(
                id: UUID().uuidString,
                roundId: roundId,
                stake: bet.amount,
                result: "lose",
                settleMult: bet.cashout,
                crashPoint: resultCrash,
                payout: 0,
                tax: 0,
                netDelta: -bet.amount,
                userId: bet.userId,
                displayName: bet.displayName,
                createdAt: Date().timeIntervalSince1970
            )
            lastSettlement = settlement
            activeBet = nil
            onRoundSettled?(settlement)
        } else if !alreadySettled, lastSettlement == nil {
            lastSettlement = RoundSettlement(
                id: UUID().uuidString,
                roundId: roundId,
                stake: 0,
                result: "empty",
                settleMult: nil,
                crashPoint: resultCrash,
                payout: 0,
                tax: 0,
                netDelta: 0,
                userId: "",
                displayName: "",
                createdAt: Date().timeIntervalSince1970
            )
        }

        phase = .ended
        crashPoint = resultCrash
        multiplier = resultCrash
        let v = (resultCrash * 100).rounded() / 100
        if recentCrashes.last != v {
            recentCrashes.append(v)
            if recentCrashes.count > 5 {
                recentCrashes.removeFirst(recentCrashes.count - 5)
            }
        }
        if multiplierHistory.last.map({ abs($0 - resultCrash) > 0.0005 }) ?? true {
            multiplierHistory.append(resultCrash)
        }
        nextRoundStartsAt = Int64(Date().timeIntervalSince1970 * 1000) + Int64(config.autoRestartMs)
        publish()

        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(config.autoRestartMs) / 1000.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.startRound() }
        }
        if let phaseTimer {
            RunLoop.main.add(phaseTimer, forMode: .common)
        }
    }

    private func publish() {
        onStateChanged?()
    }

    // MARK: - RNG (mirror server/crash.js)

    static func nextCrashMultiplier(houseEdge: Double = 0.03, maxMultiplier: Double = 500) -> Double {
        let r = Double.random(in: 0..<1)
        if r < 0.005 {
            return 1 + Double(Int.random(in: 0..<50)) / 100
        }
        let e = 1 - houseEdge
        let m = e / (1 - r * 0.9999)
        let capped = min(maxMultiplier, m)
        return max(1.01, floor(capped * 100) / 100)
    }
}
