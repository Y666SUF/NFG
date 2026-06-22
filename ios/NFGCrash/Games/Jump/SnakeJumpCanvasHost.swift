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
            if #available(iOS 15.0, *) {
                link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
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

            controller.tickFrame(
                dt: dt,
                viewWidth: Double(lastKnownWidth),
                viewHeight: Double(lastKnownHeight)
            )

            let center = controller.playerDotCenter(
                viewWidth: lastKnownWidth,
                viewHeight: lastKnownHeight
            )
            view.updatePlayerDot(
                center: center,
                controller: controller,
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
    @Published var ghostOpponents: [JumpGhostOpponent] = []
    @Published var sessionActive = false
    @Published var running = false
    @Published var profileImage: UIImage?
    @Published var sessionPoints = 0
    @Published var lifetimeJumpEarned = 0
    private(set) var trailDots: [(x: CGFloat, y: CGFloat, alpha: CGFloat)] = []

    var onMilestone: (() async -> Void)?
    var onGameOver: ((Int) async -> Void)?
    var onProgressTick: ((Int, Int) -> Void)?

    /// Drawn horizontal position — updated only by thumb *delta* while finger is down.
    private(set) var displayScreenX: CGFloat = 0
    private var touchDown = false
    private var steeringActive = false
    private var milestoneSync = 0
    private var vsProgressTick = 0
    private var localMatchSeed: Int?

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
            resetEngine(viewWidth: w, matchSeed: seed)
        } else {
            resetEngine(viewWidth: w)
        }
        sessionActive = true
        running = true
        displayScreenX = viewWidth / 2
        engine.setFingerTarget(screenX: Double(displayScreenX), viewWidth: w)
    }

    func configureMatchSeed(_ seed: Int?) {
        localMatchSeed = seed
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
        if vsProgressTick % 8 == 0 {
            onProgressTick?(engine.currentHeight, sessionPoints)
        }
        vsProgressTick += 1
        if engine.gameOver {
            running = false
            sessionActive = false
            resetSteering()
            trailDots.removeAll()
            let height = engine.currentHeight
            Task { await onGameOver?(height) }
        }
    }

    func resetEngine(viewWidth: Double, matchSeed: Int? = nil) {
        if let matchSeed {
            engine.setMatchSeed(matchSeed)
        } else {
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

        for opp in controller.ghostOpponents {
            let ox = CGFloat(opp.x) * scaleX + w * 0.5
            let oy = h - CGFloat(opp.worldY - cam) + yOffset
            if oy < -30 || oy > h + 30 { continue }
            drawGhostSnake(ctx: ctx, x: ox, y: oy, fill: opp.fill, ring: opp.ring)
        }
    }

    private func drawSky(ctx: CGContext, width: CGFloat, height: CGFloat, heightM: Int, elapsed: Double) {
        let (top, mid, bottom) = SnakeJumpCasinoDraw.skyGradient(heightM: heightM)
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [top.cgColor, mid.cgColor, bottom.cgColor] as CFArray,
            locations: [0, 0.55, 1]
        )!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: width * 0.5, y: 0), end: CGPoint(x: width * 0.5, y: height), options: [])
        SnakeJumpCasinoDraw.drawAnimatedSky(ctx: ctx, width: width, height: height, heightM: heightM, elapsed: elapsed)
    }

    private func drawGhostSnake(ctx: CGContext, x: CGFloat, y: CGFloat, fill: String, ring: String) {
        let pr = SnakeJumpEngine.playerRadius * 0.82
        ctx.setAlpha(0.72)
        SnakeJumpTheme.uiColor(hex: fill, fallback: UIColor(red: 0.58, green: 0.64, blue: 0.71, alpha: 1)).setFill()
        ctx.fillEllipse(in: CGRect(x: x - pr, y: y - pr, width: pr * 2, height: pr * 2))
        SnakeJumpTheme.uiColor(hex: ring, fallback: UIColor(red: 0.80, green: 0.84, blue: 0.88, alpha: 1)).setStroke()
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: x - pr, y: y - pr, width: pr * 2, height: pr * 2))
        ctx.setAlpha(1)
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
