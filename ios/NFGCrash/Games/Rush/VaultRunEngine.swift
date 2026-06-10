import CoreGraphics
import Foundation

/// Temple Run–style 3-lane endless runner logic (distance in meters, aligned with NFG Jump milestones).
struct VaultRunEngine {
    enum PlayerAction: Equatable {
        case running
        case jumping
        case sliding
    }

    enum ObstacleKind: Equatable {
        case block
        case jumpBar
        case slideBar
    }

    struct Obstacle: Identifiable, Equatable {
        let id: UUID
        var lane: Int
        var z: CGFloat
        var kind: ObstacleKind
    }

    static let laneCount = 3
    static let laneSpacing: CGFloat = 2.35
    static let milestoneBaseStep = 400
    static let milestoneBaseReward = 3000
    static let milestoneRewardGrowth = 600
    static let jumpDuration: CGFloat = 0.55
    static let slideDuration: CGFloat = 0.65
    static let maxJumpHeight: CGFloat = 1.45
    static let baseSpeed: CGFloat = 13.5
    static let maxSpeed: CGFloat = 28
    static let speedLerpRate: CGFloat = 2.8

    var lane = 1
    var displayLane: CGFloat = 1
    var action: PlayerAction = .running
    var actionTimer: CGFloat = 0
    var jumpY: CGFloat = 0

    var distance: CGFloat = 0
    var speed: CGFloat = baseSpeed
    private var targetSpeed: CGFloat = baseSpeed
    var elapsed: CGFloat = 0
    var alive = true
    var gameOver = false
    var maxDistance: Int = 0
    private(set) var difficultyTier = 0

    var obstacles: [Obstacle] = []
    var rng = SystemRandomNumberGenerator()

    private var spawnCooldown: CGFloat = 0
    private var milestoneCursor = 0

    var playerX: CGFloat {
        (displayLane - 1) * Self.laneSpacing
    }

    static func laneX(lane: Int) -> CGFloat {
        CGFloat(lane - 1) * laneSpacing
    }

    var currentDistance: Int {
        max(0, Int(distance))
    }

    static func milestoneDistance(forTier tier: Int) -> Int {
        max(0, tier) * milestoneBaseStep
    }

    static func milestoneReward(forTier tier: Int) -> Int {
        guard tier > 0 else { return milestoneBaseReward }
        return milestoneBaseReward + (tier - 1) * milestoneRewardGrowth
    }

    static func tier(forReportDistance distance: Int) -> Int {
        guard milestoneBaseStep > 0 else { return 0 }
        return distance / milestoneBaseStep
    }

    var nextMilestoneTier: Int { milestoneCursor + 1 }

    var nextMilestoneDistance: Int {
        Self.milestoneDistance(forTier: nextMilestoneTier)
    }

    var nextMilestoneReward: Int {
        Self.milestoneReward(forTier: nextMilestoneTier)
    }

    var reachedNewMilestone: Bool {
        currentDistance >= nextMilestoneDistance
    }

    /// Combined distance + time tier for progressive difficulty.
    static func difficultyTier(distance: Int, elapsed: CGFloat) -> Int {
        let distTier = max(0, distance / 1000)
        let timeTier = max(0, Int(elapsed / 40))
        return min(12, max(distTier, timeTier))
    }

    static func targetSpeed(for tier: Int) -> CGFloat {
        let t = CGFloat(min(12, max(0, tier)))
        // Ease-out curve — ramps early, caps fairly
        let progress = t / 12
        let eased = 1 - pow(1 - progress, 1.35)
        return baseSpeed + eased * (maxSpeed - baseSpeed)
    }

    static func spawnInterval(for tier: Int) -> CGFloat {
        let t = CGFloat(min(12, max(0, tier)))
        return max(0.38, 1.5 - t * 0.09)
    }

    mutating func reset() {
        lane = 1
        displayLane = 1
        action = .running
        actionTimer = 0
        jumpY = 0
        distance = 0
        speed = Self.baseSpeed
        targetSpeed = Self.baseSpeed
        elapsed = 0
        alive = true
        gameOver = false
        maxDistance = 0
        difficultyTier = 0
        obstacles = []
        spawnCooldown = 0.75
        milestoneCursor = 0
    }

    mutating func swipeLeft() {
        guard alive, !gameOver, action != .jumping || actionTimer < Self.jumpDuration * 0.7 else { return }
        lane = max(0, lane - 1)
    }

    mutating func swipeRight() {
        guard alive, !gameOver, action != .jumping || actionTimer < Self.jumpDuration * 0.7 else { return }
        lane = min(2, lane + 1)
    }

    mutating func swipeUp() {
        guard alive, !gameOver, action == .running else { return }
        action = .jumping
        actionTimer = 0
    }

    mutating func swipeDown() {
        guard alive, !gameOver, action == .running else { return }
        action = .sliding
        actionTimer = 0
    }

    mutating func tick(dt: CGFloat) {
        guard alive, !gameOver else { return }
        let step = min(dt, 1 / 30)
        elapsed += step

        difficultyTier = Self.difficultyTier(distance: currentDistance, elapsed: elapsed)
        targetSpeed = Self.targetSpeed(for: difficultyTier)
        speed += (targetSpeed - speed) * min(1, step * Self.speedLerpRate)

        distance += speed * step
        maxDistance = max(maxDistance, currentDistance)

        displayLane += (CGFloat(lane) - displayLane) * min(1, step * 14)

        updateAction(step: step)
        moveObstacles(step: step)
        spawnObstacles(step: step)
        checkCollisions()
    }

    private mutating func updateAction(step: CGFloat) {
        switch action {
        case .running:
            jumpY = 0
        case .jumping:
            actionTimer += step
            let t = min(1, actionTimer / Self.jumpDuration)
            jumpY = sin(t * .pi) * Self.maxJumpHeight
            if actionTimer >= Self.jumpDuration {
                action = .running
                actionTimer = 0
                jumpY = 0
            }
        case .sliding:
            actionTimer += step
            if actionTimer >= Self.slideDuration {
                action = .running
                actionTimer = 0
            }
        }
    }

    private mutating func moveObstacles(step: CGFloat) {
        for i in obstacles.indices {
            obstacles[i].z -= speed * step
        }
        obstacles.removeAll { $0.z < -4 }
    }

    private mutating func spawnObstacles(step: CGFloat) {
        spawnCooldown -= step
        guard spawnCooldown <= 0 else { return }

        spawnCooldown = Self.spawnInterval(for: difficultyTier) + CGFloat.random(in: -0.08...0.12, using: &rng)
        spawnWave(tier: difficultyTier)
    }

    private mutating func spawnWave(tier: Int) {
        let baseZ = 36 + CGFloat.random(in: 0...8, using: &rng)
        let patternRoll = Double.random(in: 0...1, using: &rng)

        if tier >= 6, patternRoll < 0.22 {
            // Two-lane wall — one safe lane
            let safe = Int.random(in: 0..<Self.laneCount, using: &rng)
            for l in 0..<Self.laneCount where l != safe {
                appendObstacle(lane: l, z: baseZ, kind: .block)
            }
            return
        }

        if tier >= 4, patternRoll < 0.38 {
            // Jump bar then block in same lane (tight combo)
            let l = Int.random(in: 0..<Self.laneCount, using: &rng)
            appendObstacle(lane: l, z: baseZ, kind: .jumpBar)
            appendObstacle(lane: l, z: baseZ + 5.5, kind: .block)
            return
        }

        if tier >= 3, patternRoll < 0.48 {
            // Slide under beam + side block
            let l = Int.random(in: 0..<Self.laneCount, using: &rng)
            appendObstacle(lane: l, z: baseZ, kind: .slideBar)
            let side = (l + Int.random(in: 1...2, using: &rng)) % Self.laneCount
            appendObstacle(lane: side, z: baseZ + 2, kind: .block)
            return
        }

        if tier >= 2, patternRoll < 0.55 {
            // Double lane blocks
            let first = Int.random(in: 0..<Self.laneCount, using: &rng)
            var second = (first + Int.random(in: 1...2, using: &rng)) % Self.laneCount
            if second == first { second = (first + 1) % Self.laneCount }
            appendObstacle(lane: first, z: baseZ, kind: .block)
            appendObstacle(lane: second, z: baseZ + CGFloat.random(in: 0...3, using: &rng), kind: .block)
            return
        }

        // Standard single obstacle — mix shifts with tier
        let kind = rollObstacleKind(tier: tier)
        let lanePick = Int.random(in: 0..<Self.laneCount, using: &rng)
        appendObstacle(lane: lanePick, z: baseZ, kind: kind)

        if kind == .block, tier >= 1, Double.random(in: 0...1, using: &rng) < 0.28 {
            let second = (lanePick + Int.random(in: 1...2, using: &rng)) % Self.laneCount
            appendObstacle(lane: second, z: baseZ + 3, kind: .block)
        }
    }

    private mutating func rollObstacleKind(tier: Int) -> ObstacleKind {
        let roll = Double.random(in: 0...1, using: &rng)
        let blockBias = min(0.22, CGFloat(tier) * 0.015)
        let jumpBias = min(0.12, CGFloat(tier) * 0.008)
        if roll < 0.4 + blockBias { return .block }
        if roll < 0.68 + jumpBias { return .jumpBar }
        return .slideBar
    }

    private mutating func appendObstacle(lane: Int, z: CGFloat, kind: ObstacleKind) {
        obstacles.append(Obstacle(id: UUID(), lane: lane, z: z, kind: kind))
    }

    private mutating func checkCollisions() {
        let hitZ: ClosedRange<CGFloat> = -0.2...1.8
        for obs in obstacles where obs.lane == lane && hitZ.contains(obs.z) {
            switch obs.kind {
            case .block:
                endRun()
                return
            case .jumpBar:
                if action != .jumping || jumpY < 0.45 {
                    endRun()
                    return
                }
            case .slideBar:
                if action != .sliding {
                    endRun()
                    return
                }
            }
        }
    }

    mutating func endRun() {
        alive = false
        gameOver = true
    }

    mutating func acknowledgeMilestone() {
        milestoneCursor += 1
    }
}
