import SwiftUI
import UIKit

struct SnakeJumpCanvasHost: UIViewRepresentable {
    @ObservedObject var controller: SnakeJumpCanvasController

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context: Context) -> SnakeJumpCanvasView {
        let view = SnakeJumpCanvasView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: SnakeJumpCanvasView, context: Context) {
        context.coordinator.controller = controller
        uiView.controller = controller
    }

    static func dismantleUIView(_ uiView: SnakeJumpCanvasView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    @MainActor
    final class Coordinator: NSObject {
        var controller: SnakeJumpCanvasController
        private weak var canvasView: SnakeJumpCanvasView?
        private var displayLink: CADisplayLink?
        private var lastTimestamp: CFTimeInterval = 0
        private var lastKnownWidth: CGFloat = 320
        private var lastKnownHeight: CGFloat = 400

        init(controller: SnakeJumpCanvasController) {
            self.controller = controller
        }

        func attach(to view: SnakeJumpCanvasView) {
            canvasView = view
            view.touchHandler = self
            view.controller = controller
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            let perf = SnakeJumpPerformanceSettings.current
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(
                    minimum: Float(perf.minFPS),
                    maximum: Float(perf.maxFPS),
                    preferred: Float(perf.preferredFPS)
                )
            } else {
                link.preferredFramesPerSecond = perf.preferredFPS
            }
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func teardown() {
            displayLink?.invalidate()
            displayLink = nil
            canvasView?.touchHandler = nil
            canvasView?.controller = nil
            canvasView = nil
        }

        func handleTouchBegan(at screenX: CGFloat, viewWidth: CGFloat) {
            if !controller.running {
                controller.beginLocalRun(viewWidth: viewWidth)
            }
            controller.touchBegan(at: screenX, viewWidth: viewWidth)
            syncPlayerDot()
        }

        func handleTouchMoved(at screenX: CGFloat, viewWidth: CGFloat) {
            controller.touchMoved(at: screenX, viewWidth: viewWidth)
            syncPlayerDot()
        }

        func handleFingerRelease() {
            controller.touchEnded()
        }

        private func syncPlayerDot() {
            guard let view = canvasView else { return }
            let w = max(view.bounds.width, 1)
            let h = max(view.bounds.height, 1)
            let center = controller.playerDotCenter(viewWidth: w, viewHeight: h)
            view.updatePlayerDot(
                center: center,
                controller: controller,
                engine: controller.engine
            )
        }

        @objc private func step(_ link: CADisplayLink) {
            guard let view = canvasView else { return }
            if lastTimestamp == 0 { lastTimestamp = link.timestamp }
            let dt = min(0.05, link.timestamp - lastTimestamp)
            lastTimestamp = link.timestamp

            if view.bounds.width > 1 { lastKnownWidth = view.bounds.width }
            if view.bounds.height > 1 { lastKnownHeight = view.bounds.height }

            controller.refreshLivePlayersDisplay()
            controller.tickFrame(
                dt: dt,
                viewWidth: Double(lastKnownWidth),
                viewHeight: Double(lastKnownHeight)
            )
            controller.sendVSNetworkUpdateIfNeeded()

            let center = controller.playerDotCenter(
                viewWidth: lastKnownWidth,
                viewHeight: lastKnownHeight
            )
            view.updatePlayerDot(
                center: center,
                controller: controller,
                engine: controller.engine
            )
            view.updateLivePlayers(
                controller.livePlayerRenders,
                cameraAnchorY: controller.engine.cameraAnchorY,
                viewWidth: lastKnownWidth,
                viewHeight: lastKnownHeight,
                engine: controller.engine
            )
            view.setNeedsDisplay()
        }
    }
}

@MainActor
final class SnakeJumpCanvasController: ObservableObject {
    let engine = SnakeJumpEngine()
    @Published var skinFill = "#596ff2"
    @Published var skinRing = "#f2c733"
    private(set) var livePlayerRenders: [JumpLivePlayerRender] = []
    @Published var sessionActive = false
    @Published var running = false
    @Published var profileImage: UIImage?
    @Published var sessionPoints = 0
    @Published var lifetimeJumpEarned = 0
    private(set) var trailDots: [(x: CGFloat, y: CGFloat, alpha: CGFloat)] = []

    var onMilestone: (() async -> Void)?
    var onGameOver: ((Int) async -> Void)?
    var onProgressTick: ((Int, Int) -> Void)?
    var onVsNetworkTick: ((Double, Double, Double, Int, Int, Double) -> Void)?

    /// Drawn horizontal position — updated only by thumb *delta* while finger is down.
    private(set) var displayScreenX: CGFloat = 0
    private var touchDown = false
    private var steeringActive = false
    private var milestoneSync = 0
    private var lastProgressPersistAt: CFTimeInterval = 0
    private var lastPersistedHeight = 0
    private var localMatchSeed: Int?
    private var vsMatchStartedAtMs: Int64?

    private struct LiveNetworkSnapshot {
        let id: String
        var displayName: String?
        var playerX: Double
        var playerY: Double
        var velocityY: Double
        var fill: String
        var ring: String
        var eliminated: Bool
        var receivedAt: CFTimeInterval
    }

    private var liveNetworkHistory: [String: [LiveNetworkSnapshot]] = [:]
    private let liveHistoryLimit = 12
    /// Small buffer so we interpolate between two known samples (smooth bounce / movement).
    private let liveInterpolationDelay: CFTimeInterval = 0.06
    private var lastNetworkSendAt: CFTimeInterval = 0
    private var lastSentX = 0.0
    private var lastSentY = 0.0
    private var lastSentVelocityY = 0.0

    var isVSReportingActive: Bool {
        localMatchSeed != nil && sessionActive && running
    }

    static let playerDrawScale: CGFloat = 1.1
    static let worldScreenYOffset: CGFloat = -40

    func playerDotCenter(viewWidth: CGFloat, viewHeight: CGFloat) -> CGPoint {
        let w = max(viewWidth, 1)
        let h = max(viewHeight, 1)
        let sx = steeringActive ? displayScreenX : CGFloat(
            engine.screenX(fromWorldX: engine.playerX, viewWidth: Double(w))
        )
        let cam = engine.cameraAnchorY
        let sy = h - CGFloat(engine.playerY - cam) + Self.worldScreenYOffset
        return CGPoint(x: sx, y: sy)
    }

    func touchBegan(at screenX: CGFloat, viewWidth: CGFloat) {
        steeringActive = true
        touchDown = true
        // Position updates on move only — tapping a new side won't teleport.
    }

    func touchMoved(at screenX: CGFloat, viewWidth: CGFloat) {
        guard touchDown else { return }
        // Absolute 1:1 — emoji sits under thumb while sliding (TikTok emoji-jump style).
        let target = clampScreenX(screenX, viewWidth: viewWidth)
        applyDisplayScreenX(target, viewWidth: viewWidth)
    }

    func touchEnded() {
        touchDown = false
    }

    func resetSteering() {
        steeringActive = false
        touchDown = false
        displayScreenX = 0
        trailDots.removeAll()
        engine.clearFingerTarget()
    }

    func beginLocalRun(viewWidth: CGFloat) {
        guard !running else { return }
        let w = max(Double(viewWidth), 280)
        if let seed = localMatchSeed {
            resetEngine(viewWidth: w, matchSeed: seed, matchStartedAtMs: vsMatchStartedAtMs)
        } else {
            resetEngine(viewWidth: w)
        }
        if let startedAt = vsMatchStartedAtMs {
            engine.alignElapsedToMatchStart(startedAtMs: startedAt)
        }
        sessionActive = true
        running = true
        displayScreenX = viewWidth / 2
        engine.setFingerTarget(screenX: Double(displayScreenX), viewWidth: w)
    }

    /// VS match — everyone starts together on the shared map (no touch required).
    func autoStartVSMatch(viewWidth: CGFloat, startedAtMs: Int64?) {
        vsMatchStartedAtMs = startedAtMs
        guard let seed = localMatchSeed else { return }
        let w = max(Double(viewWidth), SnakeJumpEngine.vsCanonicalViewWidth)
        resetEngine(viewWidth: w, matchSeed: seed, matchStartedAtMs: startedAtMs)
        sessionActive = true
        running = true
        displayScreenX = viewWidth / 2
        engine.setFingerTarget(screenX: Double(displayScreenX), viewWidth: w)
    }

    func configureMatchSeed(_ seed: Int?) {
        localMatchSeed = seed
        if seed == nil {
            vsMatchStartedAtMs = nil
            engine.clearVSMode()
        }
    }

    func applyLiveOpponents(_ opponents: [JumpVsOpponent]) {
        for opp in opponents {
            applyOpponentUpdate(opp)
        }
    }

    func applyOpponentUpdate(_ opp: JumpVsOpponent) {
        let now = CACurrentMediaTime()
        let snap = LiveNetworkSnapshot(
            id: opp.id,
            displayName: opp.displayName,
            playerX: opp.playerX ?? 0,
            playerY: opp.playerY ?? Double(opp.height) + 80,
            velocityY: opp.velocityY ?? 0,
            fill: opp.fill ?? "#596ff2",
            ring: opp.ring ?? "#f2c733",
            eliminated: opp.eliminated,
            receivedAt: now
        )
        var history = liveNetworkHistory[opp.id] ?? []
        if let last = history.last,
           abs(last.playerX - snap.playerX) < 0.01,
           abs(last.playerY - snap.playerY) < 0.01,
           abs(last.velocityY - snap.velocityY) < 0.5,
           now - last.receivedAt < 0.008 {
            return
        }
        history.append(snap)
        if history.count > liveHistoryLimit {
            history.removeFirst(history.count - liveHistoryLimit)
        }
        liveNetworkHistory[opp.id] = history
    }

    func clearLiveOpponents() {
        liveNetworkHistory.removeAll()
        livePlayerRenders = []
    }

    func sendVSNetworkUpdateIfNeeded() {
        guard isVSReportingActive else { return }
        let now = CACurrentMediaTime()
        let x = engine.playerX
        let y = engine.playerY
        let vy = engine.velocityY
        let minInterval = 1.0 / 30.0
        if now - lastNetworkSendAt < minInterval,
           abs(x - lastSentX) < 0.5,
           abs(y - lastSentY) < 0.5,
           abs(vy - lastSentVelocityY) < 5 {
            return
        }
        lastNetworkSendAt = now
        lastSentX = x
        lastSentY = y
        lastSentVelocityY = vy
        onVsNetworkTick?(
            x,
            y,
            vy,
            engine.currentHeight,
            sessionPoints,
            engine.elapsed
        )
    }

    private func advanceLivePlayers() {
        guard !liveNetworkHistory.isEmpty else {
            livePlayerRenders = []
            return
        }
        let renderAnchor = CACurrentMediaTime() - liveInterpolationDelay
        var rendered: [JumpLivePlayerRender] = []
        rendered.reserveCapacity(liveNetworkHistory.count)

        for (_, history) in liveNetworkHistory {
            guard let first = history.first else { continue }
            if history.count == 1 || renderAnchor <= first.receivedAt {
                let snap = history.last ?? first
                rendered.append(renderFromSnapshot(snap, at: renderAnchor))
                continue
            }
            var older = first
            var newer = history.last ?? first
            for snap in history {
                if snap.receivedAt <= renderAnchor { older = snap }
                if snap.receivedAt >= renderAnchor {
                    newer = snap
                    break
                }
            }
            if newer.receivedAt < older.receivedAt {
                rendered.append(renderFromSnapshot(newer, at: renderAnchor))
                continue
            }
            if renderAnchor > newer.receivedAt {
                rendered.append(renderFromSnapshot(newer, at: renderAnchor))
                continue
            }
            let span = newer.receivedAt - older.receivedAt
            let alpha = span > 0.0001 ? min(1, max(0, (renderAnchor - older.receivedAt) / span)) : 1
            rendered.append(
                JumpLivePlayerRender(
                    id: newer.id,
                    displayName: newer.displayName,
                    worldX: older.playerX + (newer.playerX - older.playerX) * alpha,
                    worldY: older.playerY + (newer.playerY - older.playerY) * alpha,
                    fill: newer.fill,
                    ring: newer.ring,
                    eliminated: newer.eliminated
                )
            )
        }
        livePlayerRenders = rendered.sorted { $0.id < $1.id }
    }

    private func renderFromSnapshot(_ snap: LiveNetworkSnapshot, at renderAnchor: CFTimeInterval) -> JumpLivePlayerRender {
        let dt = min(0.12, max(0, renderAnchor - snap.receivedAt))
        let worldY = snap.playerY + snap.velocityY * dt
        return JumpLivePlayerRender(
            id: snap.id,
            displayName: snap.displayName,
            worldX: snap.playerX,
            worldY: worldY,
            fill: snap.fill,
            ring: snap.ring,
            eliminated: snap.eliminated
        )
    }

    func refreshLivePlayersDisplay() {
        advanceLivePlayers()
    }

    func tickFrame(dt: Double, viewWidth: Double, viewHeight: Double) {
        guard sessionActive, running else { return }
        if steeringActive {
            engine.setFingerTarget(screenX: Double(displayScreenX), viewWidth: viewWidth)
        }
        engine.tick(
            dt: dt,
            steeringActive: steeringActive,
            viewWidth: viewWidth,
            viewHeight: viewHeight
        )
        if engine.reachedNewMilestone {
            Task { await syncMilestone() }
        }
        let now = CACurrentMediaTime()
        let height = engine.currentHeight
        if now - lastProgressPersistAt >= 0.25 {
            lastProgressPersistAt = now
            if height > lastPersistedHeight { lastPersistedHeight = height }
            onProgressTick?(height, sessionPoints)
        }
        if engine.gameOver {
            running = false
            sessionActive = false
            resetSteering()
            trailDots.removeAll()
            let height = engine.currentHeight
            Task { await onGameOver?(height) }
        }
    }

    func resetEngine(viewWidth: Double, matchSeed: Int? = nil, matchStartedAtMs: Int64? = nil) {
        lastProgressPersistAt = 0
        lastPersistedHeight = 0
        if let started = matchStartedAtMs {
            vsMatchStartedAtMs = started
        }
        if let matchSeed {
            engine.setMatchSeed(matchSeed, matchStartedAtMs: vsMatchStartedAtMs)
        } else {
            engine.clearVSMode()
            localMatchSeed = nil
            vsMatchStartedAtMs = nil
            engine.reset(viewWidth: viewWidth)
        }
    }

    func recordTrail(screenX: CGFloat, screenY: CGFloat) {
        guard sessionActive, running, touchDown else { return }
        trailDots.append((screenX, screenY, 0.5))
        if trailDots.count > 6 { trailDots.removeFirst(trailDots.count - 6) }
        for i in trailDots.indices {
            trailDots[i].alpha *= 0.88
        }
    }

    private func applyDisplayScreenX(_ x: CGFloat, viewWidth: CGFloat) {
        displayScreenX = x
        engine.setFingerTarget(screenX: Double(x), viewWidth: Double(max(viewWidth, 1)))
    }

    private func clampScreenX(_ x: CGFloat, viewWidth: CGFloat) -> CGFloat {
        let w = max(viewWidth, 1)
        let margin = CGFloat(SnakeJumpEngine.playerRadius) + 4
        return min(w - margin, max(margin, x))
    }

    private func syncMilestone() async {
        guard sessionActive, milestoneSync == 0 else { return }
        milestoneSync += 1
        defer { milestoneSync -= 1 }
        await onMilestone?()
    }
}

@MainActor
protocol SnakeJumpTouchHandler: AnyObject {
    func handleTouchBegan(at screenX: CGFloat, viewWidth: CGFloat)
    func handleTouchMoved(at screenX: CGFloat, viewWidth: CGFloat)
    func handleFingerRelease()
}

extension SnakeJumpCanvasHost.Coordinator: SnakeJumpTouchHandler {}

final class SnakeJumpCanvasView: UIView {
    weak var touchHandler: SnakeJumpTouchHandler?
    weak var controller: SnakeJumpCanvasController?

    private let touchLayer = SnakeJumpTouchLayerView()
    private let playerDot = SnakeJumpPlayerDotLayerView()
    private var skyGradientCache: (tier: Int, width: Int, height: Int, gradient: CGGradient)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SnakeJumpTheme.skyBottom
        isMultipleTouchEnabled = false
        isExclusiveTouch = true
        isUserInteractionEnabled = true
        isOpaque = true
        layer.isOpaque = true

        addSubview(playerDot)
        playerDot.isUserInteractionEnabled = false
        playerDot.isHidden = true

        touchLayer.backgroundColor = .clear
        touchLayer.isUserInteractionEnabled = true
        touchLayer.isMultipleTouchEnabled = false
        touchLayer.isExclusiveTouch = true
        addSubview(touchLayer)
        touchLayer.canvas = self
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        touchLayer.frame = bounds
    }

    func updatePlayerDot(center: CGPoint, controller: SnakeJumpCanvasController, engine: SnakeJumpEngine) {
        guard controller.sessionActive, controller.running, !engine.gameOver else {
            playerDot.isHidden = true
            return
        }
        playerDot.isHidden = false
        let pr = SnakeJumpEngine.playerRadius * SnakeJumpCanvasController.playerDrawScale
        let pulse = 0.82 + 0.18 * sin(engine.elapsed * 4.2)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerDot.apply(
            center: center,
            radius: CGFloat(pr),
            fill: SnakeJumpTheme.uiColor(hex: controller.skinFill, fallback: SnakeJumpTheme.defaultFill),
            ring: SnakeJumpTheme.uiColor(hex: controller.skinRing, fallback: SnakeJumpTheme.defaultRing),
            profileImage: controller.profileImage,
            pulse: CGFloat(pulse),
            boostActive: engine.boostLiftRemaining > 0
        )
        CATransaction.commit()
    }

    func deliverTouchesBegan(_ touches: Set<UITouch>, event: UIEvent?) {
        guard let touch = touches.first else { return }
        deliver(samples: coalescedSamples(for: touch, event: event), phase: .began)
    }

    func deliverTouchesMoved(_ touches: Set<UITouch>, event: UIEvent?) {
        guard touchLayer.activeTouch != nil else { return }
        guard let touch = touchLayer.activeTouch else { return }
        deliver(samples: coalescedSamples(for: touch, event: event), phase: .moved)
    }

    func deliverTouchesEnded(_ touches: Set<UITouch>, event: UIEvent?) {
        guard let touch = touchLayer.activeTouch, touches.contains(touch) else { return }
        deliver(samples: coalescedSamples(for: touch, event: event), phase: .ended)
        touchHandler?.handleFingerRelease()
    }

    private func coalescedSamples(for touch: UITouch, event: UIEvent?) -> [UITouch] {
        if let event, let coalesced = event.coalescedTouches(for: touch), !coalesced.isEmpty {
            return coalesced
        }
        return [touch]
    }

    private enum TouchPhase { case began, moved, ended }

    private func deliver(samples: [UITouch], phase: TouchPhase) {
        let w = max(bounds.width, 1)
        for sample in samples {
            let x = touchScreenX(sample)
            switch phase {
            case .began:
                touchHandler?.handleTouchBegan(at: x, viewWidth: w)
            case .moved, .ended:
                touchHandler?.handleTouchMoved(at: x, viewWidth: w)
            }
        }
    }

    private func touchScreenX(_ touch: UITouch) -> CGFloat {
        touch.preciseLocation(in: self).x
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        guard let controller else { return }

        let engine = controller.engine
        let w = bounds.width > 1 ? bounds.width : 320
        let h = bounds.height > 1 ? bounds.height : 400

        drawSky(ctx: ctx, width: w, height: h, heightM: engine.currentHeight, elapsed: engine.elapsed)

        let cam = engine.cameraAnchorY
        let scaleX = CGFloat(engine.screenScale(viewWidth: Double(w)))
        let yOffset = SnakeJumpCanvasController.worldScreenYOffset

        for plat in engine.platforms {
            let px = CGFloat(plat.centerX(at: engine.elapsed)) * scaleX + w * 0.5
            let py = h - CGFloat(plat.y - cam) + yOffset
            if py < -30 || py > h + 30 { continue }
            let pw = CGFloat(plat.width) * scaleX
            SnakeJumpCasinoDraw.drawPlatform(
                ctx: ctx,
                kind: plat.kind,
                px: px,
                py: py,
                pw: pw,
                elapsed: engine.elapsed,
                crumbleUsed: plat.crumbleUsed,
                crumbleBreakAt: plat.crumbleBreakAt,
                engineElapsed: engine.elapsed
            )
        }

        for pu in engine.powerUps where !pu.collected {
            let px = CGFloat(pu.x) * scaleX + w * 0.5
            let py = h - CGFloat(pu.y - cam) + yOffset
            if py < -20 || py > h + 20 { continue }
            SnakeJumpCasinoDraw.drawPowerUp(ctx: ctx, x: px, y: py, elapsed: engine.elapsed, seed: pu.x * 0.017)
        }

        let center = controller.playerDotCenter(viewWidth: w, viewHeight: h)
        controller.recordTrail(screenX: center.x, screenY: center.y)
    }

    func updateLivePlayers(
        _ players: [JumpLivePlayerRender],
        cameraAnchorY: Double,
        viewWidth: CGFloat,
        viewHeight: CGFloat,
        engine: SnakeJumpEngine
    ) {
        let scaleX = CGFloat(engine.screenScale(viewWidth: Double(viewWidth)))
        let yOffset = SnakeJumpCanvasController.worldScreenYOffset
        let activeIds = Set(players.map(\.id))

        for id in livePlayerDots.keys where !activeIds.contains(id) {
            livePlayerDots[id]?.removeFromSuperview()
            liveNameLabels[id]?.removeFromSuperview()
            livePlayerDots.removeValue(forKey: id)
            liveNameLabels.removeValue(forKey: id)
        }

        for player in players where !player.eliminated {
            let dot: SnakeJumpPlayerDotLayerView
            if let existing = livePlayerDots[player.id] {
                dot = existing
            } else {
                let created = SnakeJumpPlayerDotLayerView()
                created.isUserInteractionEnabled = false
                insertSubview(created, belowSubview: playerDot)
                livePlayerDots[player.id] = created
                dot = created
            }

            let label: UILabel
            if let existing = liveNameLabels[player.id] {
                label = existing
            } else {
                let created = UILabel()
                created.font = .systemFont(ofSize: 10, weight: .bold)
                created.textColor = UIColor.white.withAlphaComponent(0.92)
                created.textAlignment = .center
                created.layer.shadowColor = UIColor.black.cgColor
                created.layer.shadowOpacity = 0.85
                created.layer.shadowRadius = 2
                created.layer.shadowOffset = .zero
                created.isUserInteractionEnabled = false
                addSubview(created)
                liveNameLabels[player.id] = created
                label = created
            }

            let px = CGFloat(player.worldX) * scaleX + viewWidth * 0.5
            let py = viewHeight - CGFloat(player.worldY - cameraAnchorY) + yOffset
            if py < -60 || py > viewHeight + 60 {
                dot.isHidden = true
                label.isHidden = true
                continue
            }

            dot.isHidden = false
            label.isHidden = false
            let pr = SnakeJumpEngine.playerRadius * SnakeJumpCanvasController.playerDrawScale
            let pulse = 0.88 + 0.12 * sin(engine.elapsed * 4.2)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            dot.apply(
                center: CGPoint(x: px, y: py),
                radius: CGFloat(pr),
                fill: SnakeJumpTheme.uiColor(hex: player.fill, fallback: SnakeJumpTheme.defaultFill),
                ring: SnakeJumpTheme.uiColor(hex: player.ring, fallback: SnakeJumpTheme.defaultRing),
                profileImage: nil,
                pulse: CGFloat(pulse),
                boostActive: false
            )
            CATransaction.commit()

            let name = player.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            label.text = (name?.isEmpty == false) ? name : "Player"
            label.sizeToFit()
            label.center = CGPoint(x: px, y: py - CGFloat(pr) - 12)
        }

        for id in activeIds {
            if let player = players.first(where: { $0.id == id }), player.eliminated {
                livePlayerDots[id]?.isHidden = true
                liveNameLabels[id]?.isHidden = true
            }
        }
    }

    private var livePlayerDots: [String: SnakeJumpPlayerDotLayerView] = [:]
    private var liveNameLabels: [String: UILabel] = [:]

    private func drawSky(ctx: CGContext, width: CGFloat, height: CGFloat, heightM: Int, elapsed: Double) {
        let tier = SnakeJumpCasinoDraw.skyTier(heightM: heightM)
        let (top, mid, bottom) = SnakeJumpCasinoDraw.skyGradient(heightM: heightM)
        let wKey = Int(width.rounded())
        let hKey = Int(height.rounded())
        let gradient: CGGradient
        if let cached = skyGradientCache,
           cached.tier == tier,
           cached.width == wKey,
           cached.height == hKey {
            gradient = cached.gradient
        } else {
            let built = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [top.cgColor, mid.cgColor, bottom.cgColor] as CFArray,
                locations: [0, 0.55, 1]
            )!
            skyGradientCache = (tier, wKey, hKey, built)
            gradient = built
        }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: width * 0.5, y: 0),
            end: CGPoint(x: width * 0.5, y: height),
            options: []
        )
        SnakeJumpCasinoDraw.drawAnimatedSky(
            ctx: ctx,
            width: width,
            height: height,
            heightM: heightM,
            elapsed: elapsed,
            liteEffects: SnakeJumpPerformanceSettings.current.liteVisualEffects
        )
    }
}

/// Transparent layer above the playfield — always receives thumb touches.
private final class SnakeJumpTouchLayerView: UIView {
    weak var canvas: SnakeJumpCanvasView?
    weak var activeTouch: UITouch?

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -12, dy: -12).contains(point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard activeTouch == nil, let touch = touches.first else { return }
        activeTouch = touch
        canvas?.deliverTouchesBegan(touches, event: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        canvas?.deliverTouchesMoved(touches, event: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let activeTouch, touches.contains(activeTouch) {
            canvas?.deliverTouchesEnded(touches, event: event)
            self.activeTouch = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let activeTouch, touches.contains(activeTouch) {
            canvas?.deliverTouchesEnded(touches, event: event)
            self.activeTouch = nil
        }
    }
}

/// Lightweight UIView player — position updates every display frame, not tied to `draw(_:)`.
private final class SnakeJumpPlayerDotLayerView: UIView {
    private let glowView = UIView()
    private let fillView = UIView()
    private let imageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = false

        glowView.isUserInteractionEnabled = false
        addSubview(glowView)

        fillView.clipsToBounds = true
        fillView.isUserInteractionEnabled = false
        addSubview(fillView)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        fillView.addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        center: CGPoint,
        radius: CGFloat,
        fill: UIColor,
        ring: UIColor,
        profileImage: UIImage?,
        pulse: CGFloat,
        boostActive: Bool
    ) {
        let size = radius * 2
        bounds = CGRect(x: 0, y: 0, width: size, height: size)
        self.center = center

        let glowR = radius * (1.55 + pulse * 0.25)
        glowView.frame = CGRect(x: size * 0.5 - glowR, y: size * 0.5 - glowR, width: glowR * 2, height: glowR * 2)
        glowView.layer.cornerRadius = glowR
        if boostActive {
            glowView.backgroundColor = SnakeJumpTheme.climbGold.withAlphaComponent(0.25 * pulse)
        } else {
            glowView.backgroundColor = fill.withAlphaComponent(0.14 * pulse)
        }

        fillView.frame = CGRect(x: 0, y: 0, width: size, height: size)
        fillView.backgroundColor = fill
        fillView.layer.cornerRadius = radius
        fillView.layer.borderColor = ring.cgColor
        fillView.layer.borderWidth = max(3, radius * 0.12)

        imageView.frame = fillView.bounds
        imageView.layer.cornerRadius = radius
        imageView.image = profileImage
        imageView.isHidden = profileImage == nil
    }
}
