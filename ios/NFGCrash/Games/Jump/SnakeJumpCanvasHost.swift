import SwiftUI
import UIKit

struct SnakeJumpCanvasHost: UIViewRepresentable {
    @ObservedObject var controller: SnakeJumpCanvasController

    func makeUIView(context: Context) -> SnakeJumpCanvasView {
        let view = SnakeJumpCanvasView()
        view.controller = controller
        return view
    }

    func updateUIView(_ uiView: SnakeJumpCanvasView, context: Context) {
        uiView.controller = controller
    }
}

@MainActor
final class SnakeJumpCanvasController: ObservableObject {
    let engine = SnakeJumpEngine()
    @Published var moveLeft = false
    @Published var moveRight = false
    @Published var steer: Double = 0
    @Published var skinFill = "#596ff2"
    @Published var skinRing = "#f2c733"
    @Published var ghostOpponents: [JumpGhostOpponent] = []
    @Published var sessionActive = false
    @Published var running = false
    @Published var profileImage: UIImage?
    var sessionPoints = 0
    private(set) var trailDots: [(x: CGFloat, y: CGFloat, alpha: CGFloat)] = []

    var onMilestone: (() async -> Void)?
    var onGameOver: ((Int) async -> Void)?
    var onProgressTick: ((Int, Int) -> Void)?

    private var milestoneSync = 0
    private var vsProgressTick = 0

    func resetEngine(viewWidth: Double, matchSeed: Int? = nil) {
        if let matchSeed {
            engine.setMatchSeed(matchSeed)
        } else {
            engine.reset(viewWidth: viewWidth)
        }
    }

    func tick(dt: Double, viewWidth: Double, viewHeight: Double) async {
        guard sessionActive, running else { return }
        engine.tick(
            dt: dt,
            steer: steer,
            moveLeft: moveLeft,
            moveRight: moveRight,
            viewWidth: viewWidth,
            viewHeight: viewHeight
        )
        if engine.reachedNewMilestone {
            await syncMilestone()
        }
        if vsProgressTick % 8 == 0 {
            onProgressTick?(engine.currentHeight, sessionPoints)
        }
        vsProgressTick += 1
        if engine.gameOver {
            running = false
            sessionActive = false
            trailDots.removeAll()
            let height = engine.currentHeight
            await onGameOver?(height)
        }
    }

    func recordTrail(screenX: CGFloat, screenY: CGFloat) {
        guard sessionActive, running else { return }
        trailDots.append((screenX, screenY, 0.55))
        if trailDots.count > 14 { trailDots.removeFirst(trailDots.count - 14) }
        for i in trailDots.indices {
            trailDots[i].alpha *= 0.88
        }
    }

    private func syncMilestone() async {
        guard sessionActive, milestoneSync == 0 else { return }
        milestoneSync += 1
        defer { milestoneSync -= 1 }
        await onMilestone?()
    }
}

final class SnakeJumpCanvasView: UIView {
    weak var controller: SnakeJumpCanvasController? {
        didSet { setNeedsDisplay() }
    }

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SnakeJumpTheme.skyBottom
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        startDisplayLink()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        applySteer(from: touches)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        applySteer(from: touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        controller?.steer = 0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        controller?.steer = 0
    }

    private func applySteer(from touches: Set<UITouch>) {
        guard let touch = touches.first, let controller else { return }
        let x = touch.location(in: self).x
        let w = max(bounds.width, 1)
        controller.steer = ((x / w) - 0.5) * 2
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        displayLink?.invalidate()
    }

    private func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func step(_ link: CADisplayLink) {
        guard let controller else {
            setNeedsDisplay()
            return
        }
        if lastTimestamp == 0 { lastTimestamp = link.timestamp }
        let dt = min(0.05, link.timestamp - lastTimestamp)
        lastTimestamp = link.timestamp
        let width = max(bounds.width, 280)
        let height = max(bounds.height, 320)
        Task { @MainActor in
            await controller.tick(dt: dt, viewWidth: width, viewHeight: height)
            self.setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let controller else { return }
        let engine = controller.engine
        let w = bounds.width
        let h = bounds.height

        drawSky(ctx: ctx, width: w, height: h, heightM: engine.currentHeight)

        let cam = engine.cameraAnchorY
        let scaleX = w / (engine.lastViewWidth * 1.1)

        for plat in engine.platforms {
            let px = plat.centerX(at: engine.elapsed) * scaleX + w * 0.5
            let py = h - (plat.y - cam) - 40
            if py < -30 || py > h + 30 { continue }
            let pw = plat.width * scaleX
            SnakeJumpTheme.platformColor(kind: plat.kind).setFill()
            ctx.fill(CGRect(x: px - pw * 0.5, y: py - 6, width: pw, height: 12))
            if plat.kind == "deadly" {
                drawDeadlySpikes(ctx: ctx, px: px, py: py, pw: pw)
            }
        }

        for pu in engine.powerUps where !pu.collected {
            let px = pu.x * scaleX + w * 0.5
            let py = h - (pu.y - cam) - 40
            if py < -20 || py > h + 20 { continue }
            drawGlowingPowerUp(ctx: ctx, x: px, y: py, elapsed: engine.elapsed, seed: pu.x * 0.017)
        }

        let playerScreenX = engine.playerX * scaleX + w * 0.5
        let playerScreenY = h - (engine.playerY - cam) - 40
        let pr = SnakeJumpEngine.playerRadius * 0.55
        controller.recordTrail(screenX: playerScreenX, screenY: playerScreenY)

        let fill = SnakeJumpTheme.uiColor(hex: controller.skinFill, fallback: SnakeJumpTheme.defaultFill)
        let ring = SnakeJumpTheme.uiColor(hex: controller.skinRing, fallback: SnakeJumpTheme.defaultRing)
        let trailR = pr * 0.42
        for dot in controller.trailDots where dot.alpha > 0.04 {
            fill.withAlphaComponent(dot.alpha * 0.45).setFill()
            ring.withAlphaComponent(dot.alpha * 0.35).setStroke()
            let rect = CGRect(x: dot.x - trailR, y: dot.y - trailR, width: trailR * 2, height: trailR * 2)
            ctx.fillEllipse(in: rect)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: rect)
        }

        if engine.boostLiftRemaining > 0 {
            drawActiveBoostAura(ctx: ctx, x: playerScreenX, y: playerScreenY, elapsed: engine.elapsed)
        }

        fill.setFill()
        ctx.fillEllipse(in: CGRect(x: playerScreenX - pr, y: playerScreenY - pr, width: pr * 2, height: pr * 2))
        if let img = controller.profileImage {
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: playerScreenX - pr, y: playerScreenY - pr, width: pr * 2, height: pr * 2))
            ctx.clip()
            img.draw(in: CGRect(x: playerScreenX - pr, y: playerScreenY - pr, width: pr * 2, height: pr * 2))
            ctx.restoreGState()
        }
        ring.setStroke()
        ctx.setLineWidth(2.5)
        ctx.strokeEllipse(in: CGRect(x: playerScreenX - pr, y: playerScreenY - pr, width: pr * 2, height: pr * 2))

        for opp in controller.ghostOpponents {
            let ox = opp.x * scaleX + w * 0.5
            let oy = h - (opp.worldY - cam) - 40
            if oy < -30 || oy > h + 30 { continue }
            drawGhostSnake(ctx: ctx, x: ox, y: oy, fill: opp.fill, ring: opp.ring)
        }
    }

    private func drawSky(ctx: CGContext, width: CGFloat, height: CGFloat, heightM: Int) {
        let tier = min(8, heightM / 7500)
        let colors: [(UIColor, UIColor, UIColor)] = [
            (SnakeJumpTheme.skyTop, SnakeJumpTheme.skyMid, SnakeJumpTheme.skyBottom),
            (UIColor(red: 0.10, green: 0.06, blue: 0.19, alpha: 1), UIColor(red: 0.16, green: 0.09, blue: 0.28, alpha: 1), UIColor(red: 0.06, green: 0.04, blue: 0.09, alpha: 1)),
            (UIColor(red: 0.24, green: 0.16, blue: 0.35, alpha: 1), UIColor(red: 0.42, green: 0.23, blue: 0.45, alpha: 1), UIColor(red: 0.10, green: 0.06, blue: 0.16, alpha: 1)),
            (UIColor(red: 0.36, green: 0.49, blue: 1, alpha: 1), UIColor(red: 0.56, green: 0.71, blue: 1, alpha: 1), UIColor(red: 0.16, green: 0.29, blue: 0.54, alpha: 1)),
        ]
        let idx = min(tier, colors.count - 1)
        let (top, mid, bottom) = colors[idx]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [top.cgColor, mid.cgColor, bottom.cgColor] as CFArray,
            locations: [0, 0.55, 1]
        )!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: width * 0.5, y: 0), end: CGPoint(x: width * 0.5, y: height), options: [])
    }

    private func drawGhostSnake(ctx: CGContext, x: CGFloat, y: CGFloat, fill: String, ring: String) {
        let pr = SnakeJumpEngine.playerRadius * 0.45
        ctx.setAlpha(0.72)
        SnakeJumpTheme.uiColor(hex: fill, fallback: UIColor(red: 0.58, green: 0.64, blue: 0.71, alpha: 1)).setFill()
        ctx.fillEllipse(in: CGRect(x: x - pr, y: y - pr, width: pr * 2, height: pr * 2))
        SnakeJumpTheme.uiColor(hex: ring, fallback: UIColor(red: 0.80, green: 0.84, blue: 0.88, alpha: 1)).setStroke()
        ctx.setLineWidth(2)
        ctx.strokeEllipse(in: CGRect(x: x - pr, y: y - pr, width: pr * 2, height: pr * 2))
        ctx.setAlpha(1)
    }

    private func drawDeadlySpikes(ctx: CGContext, px: CGFloat, py: CGFloat, pw: CGFloat) {
        let spikeW = max(7, pw / 11)
        let spikeH: CGFloat = 11
        let count = max(2, Int(floor(pw / spikeW)))
        let step = pw / CGFloat(count)
        UIColor(red: 0.45, green: 0.06, blue: 0.06, alpha: 1).setFill()
        for i in 0..<count {
            let x = px - pw * 0.5 + CGFloat(i) * step + (step - spikeW) * 0.5
            let top = py - 6 - spikeH
            ctx.move(to: CGPoint(x: x, y: py - 6))
            ctx.addLine(to: CGPoint(x: x + spikeW * 0.5, y: top))
            ctx.addLine(to: CGPoint(x: x + spikeW, y: py - 6))
            ctx.closePath()
            ctx.fillPath()
        }
    }

    private func drawGlowingPowerUp(ctx: CGContext, x: CGFloat, y: CGFloat, elapsed: Double, seed: Double) {
        let pulse = 0.86 + 0.14 * sin(elapsed * 5.2 + seed)
        let r = 12 * pulse
        SnakeJumpTheme.climbGold.withAlphaComponent(0.35 * pulse).setFill()
        ctx.fillEllipse(in: CGRect(x: x - r * 2.1, y: y - r * 2.1, width: r * 4.2, height: r * 4.2))
        SnakeJumpTheme.climbGold.withAlphaComponent(0.75).setStroke()
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: x - r * 0.72, y: y - r * 0.72, width: r * 1.44, height: r * 1.44))
        UIColor.white.setFill()
        ctx.fillEllipse(in: CGRect(x: x - r * 0.42, y: y - r * 0.42, width: r * 0.84, height: r * 0.84))
    }

    private func drawActiveBoostAura(ctx: CGContext, x: CGFloat, y: CGFloat, elapsed: Double) {
        let pulse = 0.9 + 0.1 * sin(elapsed * 8)
        let auraY = y - 8
        SnakeJumpTheme.climbGold.withAlphaComponent(0.25 * pulse).setFill()
        ctx.fillEllipse(in: CGRect(x: x - 34 * pulse, y: auraY - 34 * pulse, width: 68 * pulse, height: 68 * pulse))
    }
}
