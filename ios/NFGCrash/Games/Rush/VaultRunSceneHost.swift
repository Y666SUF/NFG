import SwiftUI
import UIKit

@MainActor
final class VaultRunHUDState: ObservableObject {
    @Published var distance = 0
    @Published var runPeak = 0
    @Published var personalBest = 0
    @Published var sessionPointsDisplay = 0
    @Published var speedTier = 0

    var displayBest: Int { max(personalBest, runPeak) }
}

struct VaultRunSceneHost: UIViewRepresentable {
    let sessionActive: Bool
    var milestonesClaimed: Int
    var rewardPreview: Int
    var bestDistance: Int
    var resetToken: Int
    var shipHullHex: String
    var shipCockpitHex: String
    var shipTrailHex: String
    var shipStyle: String
    var equippedShipId: String
    @ObservedObject var hud: VaultRunHUDState
    var onMilestone: (Int) async -> Bool
    var onGameOver: (Int) async -> Void
    var onGameOverLocal: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(hud: hud, onMilestone: onMilestone, onGameOver: onGameOver, onGameOverLocal: onGameOverLocal)
    }

    func makeUIView(context: Context) -> VaultRunPlayUIView {
        let view = VaultRunPlayUIView()
        view.coordinator = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: VaultRunPlayUIView, context: Context) {
        context.coordinator.applyConfig(
            sessionActive: sessionActive,
            rewardPreview: rewardPreview,
            bestDistance: bestDistance,
            milestonesClaimed: milestonesClaimed,
            resetToken: resetToken,
            shipHullHex: shipHullHex,
            shipCockpitHex: shipCockpitHex,
            shipTrailHex: shipTrailHex,
            shipStyle: shipStyle,
            equippedShipId: equippedShipId
        )
    }

    static func dismantleUIView(_ uiView: VaultRunPlayUIView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    @MainActor
    final class Coordinator: NSObject {
        let runner = VaultRunRunner()
        let hud: VaultRunHUDState
        var sessionActive = false
        var rewardPreview = 3000
        var bestDistance = 0
        var lastResetToken = -1

        private weak var playView: VaultRunPlayUIView?
        private var displayLink: CADisplayLink?
        private var lastTick = CACurrentMediaTime()
        private var milestoneQueue: [Int] = []
        private var creditedMilestoneTiers = Set<Int>()
        private var serverMilestonesClaimed = 0
        private var milestoneSyncInFlight = 0
        private var localPoints = 0
        private var gameOverFinished = false
        private var touchStart: CGPoint?

        private let onMilestone: (Int) async -> Bool
        private let onGameOver: (Int) async -> Void
        private let onGameOverLocal: () -> Void

        init(
            hud: VaultRunHUDState,
            onMilestone: @escaping (Int) async -> Bool,
            onGameOver: @escaping (Int) async -> Void,
            onGameOverLocal: @escaping () -> Void
        ) {
            self.hud = hud
            self.onMilestone = onMilestone
            self.onGameOver = onGameOver
            self.onGameOverLocal = onGameOverLocal
        }

        func attach(to view: VaultRunPlayUIView) {
            playView = view
            view.coordinator = self
            let link = CADisplayLink(target: self, selector: #selector(step))
            link.isPaused = true
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            } else {
                link.preferredFramesPerSecond = 60
            }
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func teardown() {
            displayLink?.invalidate()
            displayLink = nil
            playView?.coordinator = nil
            playView = nil
        }

        func applyConfig(
            sessionActive: Bool,
            rewardPreview: Int,
            bestDistance: Int,
            milestonesClaimed: Int,
            resetToken: Int,
            shipHullHex: String,
            shipCockpitHex: String,
            shipTrailHex: String,
            shipStyle: String,
            equippedShipId: String
        ) {
            let paused = !sessionActive || (runner.engine.gameOver && gameOverFinished)
            if lastResetToken != resetToken {
                lastResetToken = resetToken
                self.sessionActive = sessionActive
                self.rewardPreview = rewardPreview
                self.bestDistance = bestDistance
                serverMilestonesClaimed = milestonesClaimed
                runner.engine.reset()
                if milestonesClaimed > 0 {
                    for tier in 1...milestonesClaimed {
                        runner.engine.acknowledgeMilestone()
                    }
                }
                resetSessionState(seedMilestones: milestonesClaimed)
                playView?.visualFX.reset()
                hud.distance = 0
                hud.runPeak = 0
                hud.personalBest = bestDistance
                hud.sessionPointsDisplay = 0
                playView?.sync(from: runner.engine, force: true)
            } else {
                self.sessionActive = sessionActive
                self.rewardPreview = rewardPreview
                self.bestDistance = bestDistance
                serverMilestonesClaimed = milestonesClaimed
            }
            playView?.applyCosmetics(
                shipId: equippedShipId,
                hullHex: shipHullHex,
                cockpitHex: shipCockpitHex,
                trailHex: shipTrailHex,
                style: shipStyle
            )
            setDisplayLinkPaused(paused)
        }

        private func resetSessionState(seedMilestones: Int = 0) {
            milestoneQueue = []
            creditedMilestoneTiers = seedMilestones > 0 ? Set(1...seedMilestones) : []
            serverMilestonesClaimed = seedMilestones
            milestoneSyncInFlight = 0
            localPoints = 0
            gameOverFinished = false
        }

        func setDisplayLinkPaused(_ paused: Bool) {
            displayLink?.isPaused = paused
        }

        func handleTouchBegan(_ point: CGPoint) { touchStart = point }

        func handleTouchEnded(_ point: CGPoint) {
            guard sessionActive, !runner.engine.gameOver, let start = touchStart else { return }
            touchStart = nil
            let dx = point.x - start.x
            let dy = point.y - start.y
            if abs(dx) < 24, abs(dy) < 24 { return }
            if abs(dx) > abs(dy) {
                if dx < 0 { runner.engine.swipeLeft() } else { runner.engine.swipeRight() }
            } else {
                if dy < 0 { runner.engine.swipeUp() } else { runner.engine.swipeDown() }
            }
        }

        @objc private func step(link: CADisplayLink) {
            guard sessionActive || (runner.engine.gameOver && !gameOverFinished) else { return }
            let now = link.timestamp > 0 ? link.timestamp : CACurrentMediaTime()
            let dt = CGFloat(min(0.05, now - lastTick))
            lastTick = now

            if runner.engine.gameOver {
                if !gameOverFinished {
                    gameOverFinished = true
                    publishHUD(force: true)
                    onGameOverLocal()
                    let peak = runner.engine.maxDistance
                    hud.runPeak = peak
                    hud.personalBest = max(hud.personalBest, peak)
                    NFGVaultRunPersonalBest.save(for: PlayerSession.tiktokUsername, distance: hud.personalBest)
                    Task { await onGameOver(peak) }
                    setDisplayLinkPaused(true)
                }
                playView?.sync(from: runner.engine, force: false)
                return
            }

            runner.tickFrame(dt: dt)
            if runner.engine.reachedNewMilestone { enqueueMilestones() }
            drainMilestones()
            playView?.updateVisualFX(
                dt: dt,
                engine: runner.engine,
                sessionActive: sessionActive && !runner.engine.gameOver
            )
            playView?.sync(from: runner.engine, force: false)
            publishHUD(force: false)
        }

        private func publishHUD(force: Bool) {
            let d = runner.engine.currentDistance
            let peak = max(hud.runPeak, runner.engine.maxDistance)
            let tier = runner.engine.difficultyTier
            if force || d != hud.distance || peak != hud.runPeak || tier != hud.speedTier {
                hud.distance = d
                hud.runPeak = peak
                hud.speedTier = tier
            }
            hud.personalBest = max(bestDistance, hud.personalBest, peak)
        }

        private var highestMilestoneTier: Int {
            max(creditedMilestoneTiers.max() ?? 0, serverMilestonesClaimed)
        }

        private func enqueueMilestones() {
            while true {
                let nextTier = highestMilestoneTier + milestoneQueue.count + 1
                let report = VaultRunEngine.milestoneDistance(forTier: nextTier)
                guard runner.engine.currentDistance >= report else { break }
                if milestoneQueue.contains(report) { break }
                milestoneQueue.append(report)
                if milestoneQueue.count > 4 { break }
            }
        }

        private func drainMilestones() {
            guard !milestoneQueue.isEmpty, milestoneSyncInFlight < 2 else { return }
            let report = milestoneQueue.removeFirst()
            let tier = VaultRunEngine.tier(forReportDistance: report)
            guard tier > 0, !creditedMilestoneTiers.contains(tier) else {
                drainMilestones()
                return
            }
            creditedMilestoneTiers.insert(tier)
            runner.engine.acknowledgeMilestone()
            let reward = max(rewardPreview, VaultRunEngine.milestoneReward(forTier: tier))
            localPoints += reward
            hud.sessionPointsDisplay = localPoints
            playView?.triggerMilestonePulse()
            VaultRunHaptics.milestoneReached()
            milestoneSyncInFlight += 1
            Task {
                let ok = await onMilestone(report)
                await MainActor.run {
                    milestoneSyncInFlight = max(0, milestoneSyncInFlight - 1)
                    if !ok {
                        creditedMilestoneTiers.remove(tier)
                        localPoints = max(0, localPoints - reward)
                        hud.sessionPointsDisplay = localPoints
                    }
                    drainMilestones()
                }
            }
        }
    }
}

final class VaultRunRunner {
    var engine = VaultRunEngine()
    func reset() { engine.reset() }
    func tickFrame(dt: CGFloat) { engine.tick(dt: dt) }
}

// MARK: - Core Graphics play view (same stack as NFG Jump — no SceneKit)

final class VaultRunPlayUIView: UIView {
    weak var coordinator: VaultRunSceneHost.Coordinator?
    private var engine = VaultRunEngine()
    private var scrollPhase: CGFloat = 0
    private var ambientPhase: CGFloat = 0
    private var shipCosmetics = VaultRunShipCosmetics.default
    let visualFX = VaultRunVisualFXState()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = VaultRunTheme.spaceFloor
        isMultipleTouchEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { nil }

    func applyCosmetics(shipId: String, hullHex: String, cockpitHex: String, trailHex: String, style: String) {
        shipCosmetics = VaultRunShipCosmetics.from(
            shipId: shipId,
            hullHex: hullHex,
            cockpitHex: cockpitHex,
            trailHex: trailHex,
            style: style
        )
        setNeedsDisplay()
    }

    func sync(from engine: VaultRunEngine, force: Bool) {
        self.engine = engine
        scrollPhase = engine.distance.truncatingRemainder(dividingBy: 1)
        ambientPhase = engine.elapsed.truncatingRemainder(dividingBy: 6.28)
        setNeedsDisplay()
    }

    func updateVisualFX(dt: CGFloat, engine: VaultRunEngine, sessionActive: Bool) {
        let layout = VaultRunPerspectiveLayout(width: bounds.width, height: bounds.height)
        let depth: CGFloat = 0.92
        let center = layout.pointAtNorm(engine.displayLane - 1, depth: depth)
        visualFX.update(
            dt: dt,
            shipCenter: center,
            trailColor: shipCosmetics.trail,
            cockpitColor: shipCosmetics.cockpit,
            trailTier: shipCosmetics.trailTier,
            speed: engine.speed,
            sessionActive: sessionActive
        )
    }

    func triggerMilestonePulse() {
        let layout = VaultRunPerspectiveLayout(width: bounds.width, height: bounds.height)
        let center = layout.pointAtNorm(engine.displayLane - 1, depth: 0.92)
        visualFX.triggerMilestone(at: center, trail: shipCosmetics.trail, cockpit: shipCosmetics.cockpit)
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let w = rect.width
        let h = rect.height
        guard w > 8, h > 8 else { return }

        drawEnvironment(in: rect, context: ctx)
        let layout = VaultRunPerspectiveLayout(width: w, height: h)
        drawDriftingAsteroids(layout: layout, context: ctx)
        drawFlightCorridor(layout: layout, context: ctx)
        drawObstacles(layout: layout, context: ctx)
        let shipCenter = layout.pointAtNorm(engine.displayLane - 1, depth: 0.92)
        visualFX.draw(in: ctx, shipCenter: shipCenter, cosmetics: shipCosmetics)
        drawPlayer(layout: layout, context: ctx)
        drawVignette(in: rect, context: ctx)
    }

    private func drawEnvironment(in rect: CGRect, context ctx: CGContext) {
        VaultRunDraw.fillGradient(ctx, in: rect, top: VaultRunTheme.spaceTop, bottom: VaultRunTheme.spaceFloor)

        // Nebula washes
        ctx.setFillColor(VaultRunTheme.nebulaPurple.withAlphaComponent(0.22).cgColor)
        ctx.fillEllipse(in: CGRect(x: rect.width * 0.55, y: rect.height * 0.08, width: rect.width * 0.55, height: rect.height * 0.35))
        ctx.setFillColor(VaultRunTheme.nebulaCyan.withAlphaComponent(0.16).cgColor)
        ctx.fillEllipse(in: CGRect(x: -rect.width * 0.1, y: rect.height * 0.2, width: rect.width * 0.5, height: rect.height * 0.3))

        // Distant planet
        let planetCenter = CGPoint(x: rect.width * 0.78, y: rect.height * 0.18)
        ctx.setFillColor(UIColor(red: 0.35, green: 0.28, blue: 0.55, alpha: 0.55).cgColor)
        ctx.fillEllipse(in: CGRect(x: planetCenter.x - 28, y: planetCenter.y - 28, width: 56, height: 56))
        ctx.setFillColor(UIColor(red: 0.55, green: 0.45, blue: 0.75, alpha: 0.35).cgColor)
        ctx.fillEllipse(in: CGRect(x: planetCenter.x - 18, y: planetCenter.y - 22, width: 24, height: 18))

        // Starfield with parallax twinkle
        for i in 0..<95 {
            let seed = CGFloat(i)
            let fx = VaultRunDraw.fract(sin(seed * 78.233) * 43758.5453)
            let fy = VaultRunDraw.fract(sin(seed * 12.9898) * 43758.5453)
            let depth = VaultRunDraw.fract(sin(seed * 39.425) * 23421.631)
            let drift = sin(ambientPhase + seed) * (1 + depth * 2)
            let x = rect.width * fx
            let y = rect.height * (0.04 + fy * 0.88) + drift
            let r = 0.6 + depth * 1.8
            let twinkle = 0.35 + depth * 0.55 + sin(ambientPhase * 2 + seed * 1.7) * 0.15
            VaultRunDraw.drawStar(ctx, at: CGPoint(x: x, y: y), radius: r, alpha: twinkle)
        }
    }

    private func drawDriftingAsteroids(layout: VaultRunPerspectiveLayout, context ctx: CGContext) {
        for side: CGFloat in [-1, 1] {
            for i in 0..<4 {
                let depth = 0.12 + CGFloat(i) * 0.2
                let p = layout.pointAtNorm(side * VaultRunPerspectiveLayout.trackEdgeNorm * 1.55, depth: depth)
                let scale = layout.scale(depth: depth)
                let rockW = (22 + CGFloat(i) * 6) * scale
                let rockH = rockW * 0.82
                VaultRunDraw.drawAsteroidChunk(
                    ctx,
                    center: CGPoint(x: p.x, y: p.y - rockH * 0.3),
                    width: rockW,
                    height: rockH,
                    seed: side * 10 + CGFloat(i)
                )
            }
        }
    }

    private func drawFlightCorridor(layout: VaultRunPerspectiveLayout, context ctx: CGContext) {
        let edge = VaultRunPerspectiveLayout.trackEdgeNorm
        let bands = 14
        for i in 0..<bands {
            let t0 = CGFloat(i) / CGFloat(bands)
            let t1 = CGFloat(i + 1) / CGFloat(bands)
            let phase = (t0 + scrollPhase * 0.18).truncatingRemainder(dividingBy: 1)
            let streakAlpha = 0.06 + phase * 0.1

            let top = layout.pointAtNorm(-edge, depth: t0)
            let bottom = layout.pointAtNorm(-edge, depth: t1)
            let topR = layout.pointAtNorm(edge, depth: t0)
            let bottomR = layout.pointAtNorm(edge, depth: t1)

            ctx.setFillColor(VaultRunTheme.laneGlow.withAlphaComponent(streakAlpha).cgColor)
            ctx.beginPath()
            ctx.move(to: top)
            ctx.addLine(to: topR)
            ctx.addLine(to: bottomR)
            ctx.addLine(to: bottom)
            ctx.closePath()
            ctx.fillPath()

            // Speed streaks
            if Int(phase * 14) % 3 == 0, t1 > 0.2, t1 < 0.92 {
                let laneOff = sin((t0 + t1) * 14 + scrollPhase * 4) * 0.65
                let streakCenter = layout.pointAtNorm(laneOff, depth: (t0 + t1) * 0.5)
                let sw = layout.laneCellWidth(depth: t1) * 0.08
                ctx.setFillColor(VaultRunTheme.starWhite.withAlphaComponent(0.25 + phase * 0.2).cgColor)
                ctx.fill(CGRect(x: streakCenter.x - sw * 0.5, y: streakCenter.y - 1, width: sw, height: 2))
            }
        }

        // Lane guide lines
        ctx.setStrokeColor(VaultRunTheme.laneGlow.withAlphaComponent(0.22).cgColor)
        ctx.setLineWidth(1.2)
        ctx.setLineDash(phase: scrollPhase * 12, lengths: [5, 7])
        for dividerNorm in VaultRunPerspectiveLayout.laneDividerNorms {
            let top = layout.pointAtNorm(dividerNorm, depth: 0)
            let bottom = layout.pointAtNorm(dividerNorm, depth: 1)
            ctx.beginPath()
            ctx.move(to: top)
            ctx.addLine(to: bottom)
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])

        // Corridor edge rails
        ctx.setStrokeColor(VaultRunTheme.goldTrim.withAlphaComponent(0.55).cgColor)
        ctx.setLineWidth(2)
        for railNorm: CGFloat in [-edge, edge] {
            let top = layout.pointAtNorm(railNorm, depth: 0)
            let bottom = layout.pointAtNorm(railNorm, depth: 1)
            ctx.beginPath()
            ctx.move(to: top)
            ctx.addLine(to: bottom)
            ctx.strokePath()
        }
    }

    private func drawObstacles(layout: VaultRunPerspectiveLayout, context ctx: CGContext) {
        let sorted = engine.obstacles.sorted { $0.z > $1.z }
        for obs in sorted {
            let depth = max(0, min(1, 1 - obs.z / 40))
            let center = layout.point(laneIndex: obs.lane, depth: depth)
            let scale = layout.scale(depth: depth)
            let laneW = layout.laneCellWidth(depth: depth)

            switch obs.kind {
            case .block:
                VaultRunDraw.drawAsteroidObstacle(
                    ctx,
                    center: center,
                    laneWidth: laneW,
                    scale: scale,
                    seed: CGFloat(obs.lane) + obs.z * 0.1
                )
            case .jumpBar:
                VaultRunDraw.drawDebrisBelt(ctx, center: center, laneWidth: laneW, scale: scale)
            case .slideBar:
                VaultRunDraw.drawRockTunnel(ctx, center: center, laneWidth: laneW, scale: scale)
            }
        }
    }

    private func drawPlayer(layout: VaultRunPerspectiveLayout, context ctx: CGContext) {
        let depth: CGFloat = 0.92
        let displayCenter = layout.pointAtNorm(engine.displayLane - 1, depth: depth)
        let scale = layout.scale(depth: depth)

        VaultRunDraw.drawSpaceship(
            ctx,
            center: displayCenter,
            scale: scale,
            action: engine.action,
            jumpLift: engine.jumpY,
            cosmetics: shipCosmetics,
            phase: ambientPhase
        )
    }

    private func drawVignette(in rect: CGRect, context ctx: CGContext) {
        let colors = [
            UIColor.black.withAlphaComponent(0.45).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.35).cgColor,
        ] as CFArray
        let locs: [CGFloat] = [0, 0.22, 0.78, 1]
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locs) {
            ctx.drawLinearGradient(g, start: CGPoint(x: rect.midX, y: 0), end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        coordinator?.handleTouchBegan(t.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        coordinator?.handleTouchEnded(t.location(in: self))
    }
}

private struct VaultRunPerspectiveLayout {
    /// Track edge in lane-normal space (lane 0 = −1, lane 1 = 0, lane 2 = +1).
    static let trackEdgeNorm: CGFloat = 1.0
    static let laneDividerNorms: [CGFloat] = [-0.333, 0.333]

    let width: CGFloat
    let height: CGFloat
    let horizonY: CGFloat
    let playerY: CGFloat
    let centerX: CGFloat

    init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
        horizonY = height * 0.22
        playerY = height * 0.84
        centerX = width * 0.5
    }

    func scale(depth: CGFloat) -> CGFloat {
        0.35 + depth * 0.65
    }

    func trackHalfWidth(depth: CGFloat) -> CGFloat {
        let near = width * 0.34
        let far = width * 0.075
        return far + (near - far) * depth
    }

    /// Width of one of three equal lanes at this depth.
    func laneCellWidth(depth: CGFloat) -> CGFloat {
        trackHalfWidth(depth: depth) * 2 / 3 * 0.88
    }

    /// Lane index 0…2 → screen point (centers at −1, 0, +1).
    func point(laneIndex: Int, depth: CGFloat) -> CGPoint {
        pointAtNorm(Self.norm(forLaneIndex: laneIndex), depth: depth)
    }

    func pointAtNorm(_ laneNorm: CGFloat, depth: CGFloat) -> CGPoint {
        let half = trackHalfWidth(depth: depth)
        let x = centerX + laneNorm * half
        let y = horizonY + depth * (playerY - horizonY)
        return CGPoint(x: x, y: y)
    }

    static func norm(forLaneIndex lane: Int) -> CGFloat {
        CGFloat(lane - 1)
    }
}

enum VaultRunHaptics {
    static func milestoneReached() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
