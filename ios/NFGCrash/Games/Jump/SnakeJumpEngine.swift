import Foundation

struct JumpPlatform: Identifiable {
    let id: UUID
    var kind: String
    var x: Double
    var y: Double
    var width: Double
    var movePhase: Double
    var moveSpan: Double
    var moveSpeed: Double
    var crumbleUsed: Bool
    var crumbleBreakAt: Double? = nil
    var headFacesRight: Bool

    func centerX(at time: Double) -> Double {
        if kind != "moving" || moveSpan <= 0 || moveSpeed <= 0 { return x }
        let travel = moveSpan * 2
        let period = travel / moveSpeed
        if period <= 0 { return x }
        var phase = ((time + movePhase).truncatingRemainder(dividingBy: period)) / period
        if phase < 0 { phase += 1 }
        let tri = phase < 0.5 ? phase * 2 : 2 - phase * 2
        return x - moveSpan + tri * travel
    }
}

struct JumpPowerUp: Identifiable {
    let id: UUID
    var x: Double
    var y: Double
    var collected: Bool
}

final class SnakeJumpEngine {
    static let playerRadius: Double = 22
    static let platformHeight: Double = 14
    static let milestoneStep: Int = 2500
    static let milestoneReward: Int = 3000
    static let horizontalSpeed: Double = 312
    static let boostTotalLift: Double = 300
    static let boostImpulseVelocity: Double = 1120
    static let baseGravity: Double = 1220
    static let baseJumpVelocity: Double = 800
    static let worldBufferAbove: Double = 10000
    static let maxPlatformCount: Int = 14
    static let materializeAhead: Double = 580
    /// Player screen anchor — 45% from top minus offset (matches fixed draw position).
    static let cameraPlayerScreenRatio: Double = 0.55
    static let physicsSubsteps: Int = 3

    var playerX: Double = 0
    var playerY: Double = 120
    var velocityX: Double = 0
    var velocityY: Double = 0
    var boostLiftRemaining: Double = 0
    var platforms: [JumpPlatform] = []
    var powerUps: [JumpPowerUp] = []
    var maxHeight: Int = 0
    var milestonesClaimed: Int = 0
    var alive: Bool = true
    var gameOver: Bool = false
    var elapsed: Double = 0
    var cameraAnchorY: Double = 0
    var lastSafeX: Double = 0
    var lastSafeY: Double = 40
    var nextSpawnY: Double = 120
    var plannedTopY: Double = 130
    var lastViewWidth: Double = 320

    private var rng: () -> Double = { Double.random(in: 0..<1) }
    private var fingerTargetX: Double?
    private(set) var fingerScreenX: Double?

    init() {
        reset(viewWidth: 320)
    }

    func setMatchSeed(_ seed: Int) {
        var state = UInt32(truncatingIfNeeded: seed == 0 ? 1 : seed)
        rng = {
            state = state &+ 0x6d2b79f5
            var t = state
            t = t &* ((t >> 15) | 1)
            t ^= t &+ (t &* (((t >> 7) | 1)))
            return Double((t ^ (t >> 14)) >> 0) / 4294967296.0
        }
        reset(viewWidth: lastViewWidth)
    }

    func reset(viewWidth: Double = 320) {
        playerX = 0
        playerY = 120
        velocityX = 0
        velocityY = 0
        boostLiftRemaining = 0
        platforms = []
        powerUps = []
        fingerTargetX = nil
        fingerScreenX = nil
        maxHeight = 0
        milestonesClaimed = 0
        alive = true
        gameOver = false
        elapsed = 0
        cameraAnchorY = 0
        lastSafeX = 0
        lastSafeY = 40
        nextSpawnY = 120
        plannedTopY = 130
        lastViewWidth = max(280, viewWidth)
        seedWorld(viewWidth: lastViewWidth)
    }

    var currentHeight: Int {
        max(0, Int(floor(playerY - 80)))
    }

    var difficultyTier: Int {
        max(0, maxHeight / 1800)
    }

    func paceMultiplier(tier: Int) -> Double {
        1 + Double(min(18, tier)) * 0.045
    }

    var nextMilestoneHeight: Int {
        (milestonesClaimed + 1) * Self.milestoneStep
    }

    var reachedNewMilestone: Bool {
        currentHeight >= nextMilestoneHeight
    }

    func tick(
        dt: Double,
        steeringActive: Bool = false,
        viewWidth: Double,
        viewHeight: Double
    ) {
        guard alive, !gameOver else { return }
        let step = min(dt, 1 / 45)
        let tier = difficultyTier
        let pace = paceMultiplier(tier: tier)
        let simStep = step * pace
        elapsed += simStep
        lastViewWidth = max(280, viewWidth)

        let gravity = Self.baseGravity + Double(tier) * 14
        let jumpVelocity = Self.baseJumpVelocity + Double(min(16, tier)) * 10

        if steeringActive {
            syncPlayerToFinger()
        }

        let halfW = playableHalfWidth(viewWidth: viewWidth)
        playerX = min(halfW, max(-halfW, playerX))

        let subDt = simStep / Double(Self.physicsSubsteps)
        for _ in 0..<Self.physicsSubsteps {
            if boostLiftRemaining > 0 {
                velocityY = max(velocityY, Self.boostImpulseVelocity * pace)
                let uplift = max(0, velocityY * subDt)
                boostLiftRemaining = max(0, boostLiftRemaining - uplift)
            }

            velocityY -= gravity * subDt
            playerY += velocityY * subDt

            if steeringActive {
                syncPlayerToFinger()
                playerX = min(halfW, max(-halfW, playerX))
            }

            tryLand(jumpVelocity: jumpVelocity)
        }

        collectPowerUps()

        if currentHeight > maxHeight { maxHeight = currentHeight }

        let targetCam = playerY - viewHeight * Self.cameraPlayerScreenRatio
        if cameraAnchorY == 0, viewHeight > 0 {
            cameraAnchorY = targetCam
        } else if targetCam > cameraAnchorY {
            let blend = min(1.0, step * 14.0)
            cameraAnchorY += (targetCam - cameraAnchorY) * blend
        }

        trimPlatforms(belowY: cameraAnchorY - 60)
        advanceWorldPlan(ceilingY: playerY + Self.worldBufferAbove, maxSteps: 2)
        let playTop = playerY + min(Self.materializeAhead, max(480, viewHeight * 0.9))
        spawnUpTo(targetY: playTop, viewWidth: viewWidth, maxSteps: 1)
        capPlatformCount()
        purgeBrokenCrumblePlatforms()

        let screenY = viewHeight - (playerY - cameraAnchorY)
        if screenY >= viewHeight - Self.playerRadius - 10 {
            alive = false
            gameOver = true
        }
    }

    func setFingerTarget(screenX: Double, viewWidth: Double) {
        let w = max(280, viewWidth)
        lastViewWidth = w
        let scale = screenScale(viewWidth: w)
        let halfW = max(60, (w * 0.5 - Self.playerRadius) / scale)
        let maxScreenX = halfW * scale + w * 0.5
        let minScreenX = w * 0.5 - halfW * scale
        let clampedScreen = min(maxScreenX, max(minScreenX, screenX))
        fingerScreenX = clampedScreen
        fingerTargetX = (clampedScreen - w * 0.5) / scale
        syncPlayerToFinger()
    }

    func clearFingerTarget() {
        fingerTargetX = nil
        fingerScreenX = nil
    }

    /// Lock player world X to finger — TikTok emoji-jump style (no lag / no skip).
    func syncPlayerToFinger() {
        guard let target = fingerTargetX else { return }
        let halfW = playableHalfWidth(viewWidth: lastViewWidth)
        playerX = min(halfW, max(-halfW, target))
        velocityX = 0
    }

    /// Legacy alias — sets follow target, does not snap position.
    func applyFingerScreenX(_ screenX: Double, viewWidth: Double) {
        setFingerTarget(screenX: screenX, viewWidth: viewWidth)
    }

    private func tryLand(jumpVelocity: Double) {
        guard velocityY <= 0 else { return }
        let footY = playerY - Self.playerRadius
        var candidates: [(index: Int, distY: Double, deadly: Bool)] = []
        let landBand = playerY + 120
        for (i, plat) in platforms.enumerated() {
            if plat.y > landBand || plat.y < playerY - 220 { continue }
            let px = plat.centerX(at: elapsed)
            let half = plat.width * 0.5
            let onX = playerX >= px - half + 6 && playerX <= px + half - 6
            let distY = abs(footY - plat.y)
            if !onX || distY >= 20 { continue }
            candidates.append((i, distY, plat.kind == "deadly"))
        }
        guard !candidates.isEmpty else { return }
        candidates.sort { a, b in
            if a.deadly != b.deadly { return !a.deadly }
            return a.distY < b.distY
        }
        let idx = candidates[0].index
        var plat = platforms[idx]
        if plat.kind == "deadly" {
            alive = false
            gameOver = true
            return
        }
        if plat.kind == "crumble" {
            if plat.crumbleUsed { return }
            plat.crumbleUsed = true
            plat.crumbleBreakAt = elapsed + 0.22
            platforms[idx] = plat
        }
        playerY = plat.y + Self.playerRadius
        velocityY = jumpVelocity
        boostLiftRemaining = 0
        lastSafeX = plat.centerX(at: elapsed)
        lastSafeY = plat.y
    }

    private func collectPowerUps() {
        for i in powerUps.indices {
            guard !powerUps[i].collected else { continue }
            let pu = powerUps[i]
            let dx = playerX - pu.x
            let dy = playerY - pu.y
            if dx * dx + dy * dy < 48 * 48 {
                powerUps[i].collected = true
                boostLiftRemaining = Self.boostTotalLift
                velocityY = Self.boostImpulseVelocity
            }
        }
    }

    func screenScale(viewWidth: Double) -> Double {
        1.0
    }

    func playableHalfWidth(viewWidth: Double) -> Double {
        let w = max(280, viewWidth)
        let scale = screenScale(viewWidth: w)
        // Match screen edges so finger X maps 1:1 to player screen X.
        return max(60, (w * 0.5 - Self.playerRadius) / scale)
    }

    func worldX(fromScreenX screenX: Double, viewWidth: Double) -> Double {
        let w = max(viewWidth, 280)
        lastViewWidth = w
        let scale = screenScale(viewWidth: w)
        return (screenX - w * 0.5) / scale
    }

    func screenX(fromWorldX worldX: Double, viewWidth: Double) -> Double {
        let w = max(viewWidth, 280)
        return worldX * screenScale(viewWidth: w) + w * 0.5
    }

    func horizontalReach(tier: Int, early: Bool) -> Double {
        early ? 88 : max(68, 98 - Double(min(tier, 16)) * 2)
    }

    private func seedWorld(viewWidth: Double) {
        platforms = [
            JumpPlatform(
                id: UUID(),
                kind: "solid",
                x: 0,
                y: 40,
                width: 120,
                movePhase: 0,
                moveSpan: 0,
                moveSpeed: 0,
                crumbleUsed: false,
                headFacesRight: true
            ),
        ]
        lastSafeX = 0
        lastSafeY = 40
        nextSpawnY = 130
        plannedTopY = 130
        spawnUpTo(targetY: 520, viewWidth: viewWidth, maxSteps: 6)
        advanceWorldPlan(ceilingY: playerY + Self.worldBufferAbove, maxSteps: 24)
    }

    private func spawnUpTo(targetY: Double, viewWidth: Double, maxSteps: Int = 8) {
        let maxX = playableHalfWidth(viewWidth: viewWidth)
        var guardCount = 0
        while nextSpawnY < targetY, guardCount < maxSteps {
            spawnGuaranteedStep(maxX: maxX)
            guardCount += 1
        }
    }

    private func spawnGuaranteedStep(maxX: Double) {
        let climbTier = max(0, Int(floor(nextSpawnY / 2250)))
        let early = nextSpawnY < 480
        let gap: Double
        if early {
            gap = 102 + rng() * 16
        } else {
            gap = 88 + rng() * 16 + Double(min(climbTier, 14)) * 3
        }
        nextSpawnY += gap
        let y = nextSpawnY
        let hReach = horizontalReach(tier: climbTier, early: early)
        let phase = rng() * Double.pi * 2
        let headRight = rng() < 0.5
        let movingShare = early ? 0.08 : min(0.48, 0.1 + Double(climbTier) * 0.03)
        let useMoving = rng() < movingShare
        let primaryKind = useMoving ? "moving" : "solid"
        let primaryWidth = early ? 88 + rng() * 16 : max(62, 106 - Double(min(climbTier, 12)) * 3)
        var anchor = lastSafeX + (rng() * 2 - 1) * hReach
        var moveSpan: Double = 0
        var moveSpeed: Double = 0
        if primaryKind == "moving" {
            let cfg = movingConfig(tier: climbTier, width: primaryWidth, maxX: maxX, anchor: anchor, hReach: hReach, early: early)
            moveSpan = cfg.span
            moveSpeed = cfg.speed
            anchor = cfg.anchor
        } else {
            anchor = min(maxX - primaryWidth * 0.4, max(-maxX + primaryWidth * 0.4, anchor))
        }
        appendPlatform(kind: primaryKind, x: anchor, y: y, width: primaryWidth, moveSpan: moveSpan, moveSpeed: moveSpeed, phase: phase, headFacesRight: headRight)
        lastSafeX = anchor
        lastSafeY = y
        let crumbleChance = early ? 0.12 : min(0.38, 0.08 + Double(climbTier) * 0.02)
        if platforms.count < Self.maxPlatformCount - 2, rng() < crumbleChance {
            spawnOptionalCrumble(maxX: maxX, y: y + 16 + rng() * 10, tier: climbTier, hReach: hReach)
        }
        if !early, platforms.count < Self.maxPlatformCount - 2 {
            let avoidLo = useMoving ? anchor - moveSpan - 24 : anchor - primaryWidth * 0.5 - 28
            let avoidHi = useMoving ? anchor + moveSpan + 24 : anchor + primaryWidth * 0.5 + 28
            spawnDecoys(maxX: maxX, y: y, tier: climbTier, avoidLo: avoidLo, avoidHi: avoidHi, hReach: hReach)
            if rng() < min(0.1, 0.04 + Double(climbTier) * 0.004) {
                powerUps.append(
                    JumpPowerUp(
                        id: UUID(),
                        x: lastSafeX + (rng() * 2 - 1) * hReach * 0.5,
                        y: y + 44 + rng() * 24,
                        collected: false
                    )
                )
            }
        }
    }

    private struct MovingConfig {
        var span: Double
        var speed: Double
        var anchor: Double
    }

    private func movingConfig(tier: Int, width: Double, maxX: Double, anchor: Double, hReach: Double, early: Bool) -> MovingConfig {
        let fullTravel = !early && rng() < 0.42
        let playable = maxX - width * 0.5 - 12
        var span = fullTravel ? min(playable, 110) : min(playable * 0.38, 64)
        span = max(32, span - Double(min(tier, 10)) * 2)
        let speed = 32 + rng() * 26 + Double(min(tier, 14)) * 2.8
        var a = min(maxX - span, max(-maxX + span, anchor))
        let lo = a - span
        let hi = a + span
        if hi < lastSafeX - hReach || lo > lastSafeX + hReach {
            a = min(maxX - span, max(-maxX + span, lastSafeX))
        }
        return MovingConfig(span: span, speed: speed, anchor: a)
    }

    private func appendPlatform(
        kind: String,
        x: Double,
        y: Double,
        width: Double,
        moveSpan: Double = 0,
        moveSpeed: Double = 0,
        phase: Double = 0,
        headFacesRight: Bool = true
    ) {
        platforms.append(
            JumpPlatform(
                id: UUID(),
                kind: kind,
                x: x,
                y: y,
                width: width,
                movePhase: phase,
                moveSpan: moveSpan,
                moveSpeed: moveSpeed,
                crumbleUsed: false,
                headFacesRight: headFacesRight
            )
        )
    }

    private func spawnDecoys(maxX: Double, y: Double, tier: Int, avoidLo: Double, avoidHi: Double, hReach: Double) {
        let deadlyChance = min(0.38, 0.1 + Double(tier) * 0.02)
        guard rng() < deadlyChance else { return }
        let decoyWidth = 68 + rng() * 22
        let minSep = max(48, hReach * 0.5)
        for _ in 0..<6 {
            let goLeft = rng() < 0.5
            var x = goLeft
                ? avoidLo - minSep - (24 + rng() * 36)
                : avoidHi + minSep + (24 + rng() * 36)
            x = min(maxX - decoyWidth * 0.4, max(-maxX + decoyWidth * 0.4, x))
            let lo = x - decoyWidth * 0.5
            let hi = x + decoyWidth * 0.5
            if hi > avoidLo - 16, lo < avoidHi + 16 { continue }
            if hi >= lastSafeX - hReach, lo <= lastSafeX + hReach { continue }
            appendPlatform(kind: "deadly", x: x, y: y, width: decoyWidth, headFacesRight: !goLeft)
            return
        }
    }

    private func spawnOptionalCrumble(maxX: Double, y: Double, tier: Int, hReach: Double) {
        let width = max(58, 84 - Double(min(tier, 8)) * 2)
        var anchor = lastSafeX + (rng() * 2 - 1) * hReach * 0.75
        anchor = min(maxX - width * 0.4, max(-maxX + width * 0.4, anchor))
        let lo = anchor - width * 0.5
        let hi = anchor + width * 0.5
        if hi < lastSafeX - hReach || lo > lastSafeX + hReach { return }
        appendPlatform(kind: "crumble", x: anchor, y: y, width: width, headFacesRight: anchor >= lastSafeX)
    }

    private func advanceWorldPlan(ceilingY: Double, maxSteps: Int) {
        let maxX = playableHalfWidth(viewWidth: lastViewWidth)
        var steps = 0
        var planY = plannedTopY
        var planSafeX = lastSafeX
        while planY < ceilingY, steps < maxSteps {
            let step = planSpawnStep(baseY: planY, safeX: planSafeX, maxX: maxX)
            planY = step.y
            planSafeX = step.safeX
            steps += 1
        }
        plannedTopY = max(plannedTopY, planY)
    }

    private struct PlanStep {
        var y: Double
        var safeX: Double
    }

    private func planSpawnStep(baseY: Double, safeX: Double, maxX: Double) -> PlanStep {
        let climbTier = max(0, Int(floor(baseY / 2250)))
        let early = baseY < 480
        let gap: Double
        if early {
            gap = 102 + rng() * 16
        } else {
            gap = 88 + rng() * 16 + Double(min(climbTier, 14)) * 3
        }
        let y = baseY + gap
        let hReach = horizontalReach(tier: climbTier, early: early)
        var anchor = safeX + (rng() * 2 - 1) * hReach
        let movingShare = early ? 0.08 : min(0.48, 0.1 + Double(climbTier) * 0.03)
        let useMoving = rng() < movingShare
        let primaryWidth = early ? 88 + rng() * 16 : max(62, 106 - Double(min(climbTier, 12)) * 3)
        if useMoving {
            let cfg = movingConfig(tier: climbTier, width: primaryWidth, maxX: maxX, anchor: anchor, hReach: hReach, early: early)
            anchor = cfg.anchor
        } else {
            anchor = min(maxX - primaryWidth * 0.4, max(-maxX + primaryWidth * 0.4, anchor))
        }
        return PlanStep(y: y, safeX: anchor)
    }

    private func trimPlatforms(belowY: Double) {
        platforms.removeAll { $0.y < belowY }
        powerUps.removeAll { $0.y < belowY - 60 }
    }

    private func purgeBrokenCrumblePlatforms() {
        platforms.removeAll { plat in
            guard plat.kind == "crumble", plat.crumbleUsed, let breakAt = plat.crumbleBreakAt else { return false }
            return elapsed >= breakAt
        }
    }

    private func capPlatformCount() {
        if platforms.count > Self.maxPlatformCount {
            platforms.removeFirst(platforms.count - Self.maxPlatformCount)
        }
    }
}
