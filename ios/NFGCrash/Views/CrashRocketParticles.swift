import SpriteKit
import SwiftUI
import UIKit

// MARK: - Exhaust (fire + smoke + sparks while flying)

struct RocketExhaustParticlesView: UIViewRepresentable {
    var rocketPosition: CGPoint
    var exhaustAngleRadians: CGFloat
    var isActive: Bool
    /// Scales SpriteKit exhaust (large at 1×, smaller as multiplier climbs).
    var intensity: CGFloat = 1

    func makeUIView(context: Context) -> SKView {
        let view = makeClearSKView()
        let scene = RocketParticleScene(size: CGSize(width: 320, height: 160))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        applyTransparentSKViewChrome(view)
        view.isHidden = !isActive
        guard let scene = context.coordinator.scene else { return }
        scene.size = view.bounds.size
        scene.updateExhaust(
            at: rocketPosition,
            angle: exhaustAngleRadians,
            active: isActive,
            intensity: intensity
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var scene: RocketParticleScene?
    }
}

// MARK: - Fall trail (sparks while plummeting)

struct RocketFallTrailParticlesView: UIViewRepresentable {
    var rocketPosition: CGPoint
    var isActive: Bool

    func makeUIView(context: Context) -> SKView {
        let view = makeClearSKView()
        let scene = RocketParticleScene(size: CGSize(width: 320, height: 160), mode: .fallTrail)
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        applyTransparentSKViewChrome(view)
        view.isHidden = !isActive
        guard let scene = context.coordinator.scene else { return }
        scene.size = view.bounds.size
        scene.updateFallTrail(at: rocketPosition, active: isActive)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var scene: RocketParticleScene?
    }
}

// MARK: - Wreck smoke (lingering after crash)

struct RocketWreckSmokeParticlesView: UIViewRepresentable {
    var position: CGPoint
    var isActive: Bool

    func makeUIView(context: Context) -> SKView {
        let view = makeClearSKView()
        let scene = RocketParticleScene(size: CGSize(width: 320, height: 160), mode: .wreckSmoke)
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        applyTransparentSKViewChrome(view)
        view.isHidden = !isActive
        guard let scene = context.coordinator.scene else { return }
        scene.size = view.bounds.size
        scene.updateWreckSmoke(at: position, active: isActive)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var scene: RocketParticleScene?
    }
}

// MARK: - Ground impact burst

struct RocketImpactParticlesView: UIViewRepresentable {
    var position: CGPoint
    var burstToken: Int

    func makeUIView(context: Context) -> SKView {
        let view = makeClearSKView()
        let scene = RocketParticleScene(size: CGSize(width: 320, height: 160), mode: .impactOnly)
        view.presentScene(scene)
        context.coordinator.scene = scene
        context.coordinator.lastBurst = -1
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        scene.size = view.bounds.size
        if burstToken != context.coordinator.lastBurst, burstToken > 0 {
            context.coordinator.lastBurst = burstToken
            scene.playImpact(at: position)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var scene: RocketParticleScene?
        var lastBurst = -1
    }
}

private func makeClearSKView() -> SKView {
    let view = SKView()
    applyTransparentSKViewChrome(view)
    return view
}

private func applyTransparentSKViewChrome(_ view: SKView) {
    view.backgroundColor = .clear
    view.allowsTransparency = true
    view.isUserInteractionEnabled = false
    view.isOpaque = false
    view.layer.isOpaque = false
    view.layer.backgroundColor = UIColor.clear.cgColor
}

// MARK: - SpriteKit scene

final class RocketParticleScene: SKScene {
    enum Mode {
        case exhaust
        case fallTrail
        case wreckSmoke
        case impactOnly
    }

    private let mode: Mode
    private let exhaustRoot = SKNode()
    private let fireEmitter = RocketParticleFactory.makeFireEmitter()
    private let smokeEmitter = RocketParticleFactory.makeSmokeEmitter()
    private let sparkEmitter = RocketParticleFactory.makeSparkEmitter()
    private let fallEmitter = RocketParticleFactory.makeFallSparkEmitter()
    private let wreckSmokeEmitter = RocketParticleFactory.makeWreckSmokeEmitter()
    private var exhaustActive = false

    init(size: CGSize, mode: Mode = .exhaust) {
        self.mode = mode
        super.init(size: size)
        switch mode {
        case .exhaust:
            addChild(exhaustRoot)
            exhaustRoot.addChild(smokeEmitter)
            exhaustRoot.addChild(fireEmitter)
            exhaustRoot.addChild(sparkEmitter)
            exhaustRoot.isHidden = true
        case .fallTrail:
            addChild(fallEmitter)
            fallEmitter.isHidden = true
        case .wreckSmoke:
            addChild(wreckSmokeEmitter)
            wreckSmokeEmitter.isHidden = true
        case .impactOnly:
            break
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateExhaust(at point: CGPoint, angle: CGFloat, active: Bool, intensity: CGFloat = 1) {
        guard mode == .exhaust else { return }
        exhaustActive = active
        exhaustRoot.isHidden = !active
        guard active, size.width > 1, size.height > 1 else {
            fireEmitter.particleBirthRate = 0
            smokeEmitter.particleBirthRate = 0
            sparkEmitter.particleBirthRate = 0
            return
        }
        let sk = Self.skPoint(from: point, sceneSize: size)
        let i = max(0.4, min(1.25, intensity))
        exhaustRoot.position = sk
        exhaustRoot.zRotation = angle + .pi
        exhaustRoot.setScale(i)
        fireEmitter.particleBirthRate = 200 * i
        smokeEmitter.particleBirthRate = 72 * i
        sparkEmitter.particleBirthRate = 48 * i
        fireEmitter.particleSpeed = 115 * (0.55 + 0.45 * i)
        fireEmitter.particleScale = 0.28 * i
        smokeEmitter.particleScale = 0.42 * i
        sparkEmitter.particleScale = 0.08 * i
        fireEmitter.targetNode = self
        smokeEmitter.targetNode = self
        sparkEmitter.targetNode = self
    }

    func updateFallTrail(at point: CGPoint, active: Bool) {
        guard mode == .fallTrail else { return }
        fallEmitter.isHidden = !active
        guard active, size.width > 1, size.height > 1 else {
            fallEmitter.particleBirthRate = 0
            return
        }
        fallEmitter.position = Self.skPoint(from: point, sceneSize: size)
        fallEmitter.particleBirthRate = 90
        fallEmitter.targetNode = self
    }

    func updateWreckSmoke(at point: CGPoint, active: Bool) {
        guard mode == .wreckSmoke else { return }
        wreckSmokeEmitter.isHidden = !active
        guard active, size.width > 1, size.height > 1 else {
            wreckSmokeEmitter.particleBirthRate = 0
            return
        }
        wreckSmokeEmitter.position = Self.skPoint(from: point, sceneSize: size)
        wreckSmokeEmitter.particleBirthRate = 28
        wreckSmokeEmitter.targetNode = self
    }

    func playImpact(at point: CGPoint) {
        guard size.width > 1, size.height > 1 else { return }
        let sk = Self.skPoint(from: point, sceneSize: size)
        let burst = RocketParticleFactory.makeImpactBurst()
        let smoke = RocketParticleFactory.makeImpactSmokePlume()
        let debris = RocketParticleFactory.makeDebrisBurst()
        burst.position = sk
        smoke.position = sk
        debris.position = sk
        addChild(smoke)
        addChild(burst)
        addChild(debris)
        let cleanup = SKAction.sequence([.wait(forDuration: 1.8), .removeFromParent()])
        burst.run(cleanup)
        smoke.run(cleanup)
        debris.run(.sequence([.wait(forDuration: 2.2), .removeFromParent()]))
    }

    override func update(_ currentTime: TimeInterval) {
        if mode == .exhaust, !exhaustActive {
            fireEmitter.particleBirthRate = 0
            smokeEmitter.particleBirthRate = 0
            sparkEmitter.particleBirthRate = 0
        }
    }

    private static func skPoint(from viewPoint: CGPoint, sceneSize: CGSize) -> CGPoint {
        CGPoint(x: viewPoint.x, y: sceneSize.height - viewPoint.y)
    }
}

// MARK: - Emitter presets

private enum RocketParticleFactory {
    static let softTexture: SKTexture = {
        let d: CGFloat = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        let img = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: d, height: d)
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawRadialGradient(
                    grad,
                    startCenter: CGPoint(x: d / 2, y: d / 2),
                    startRadius: 0,
                    endCenter: CGPoint(x: d / 2, y: d / 2),
                    endRadius: d / 2,
                    options: []
                )
            }
        }
        return SKTexture(image: img)
    }()

    static func makeFireEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.numParticlesToEmit = 0
        e.particleLifetime = 0.32
        e.particleLifetimeRange = 0.14
        e.particleSpeed = 115
        e.particleSpeedRange = 55
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.28
        e.particleAlpha = 0.98
        e.particleAlphaSpeed = -2.8
        e.particleScale = 0.28
        e.particleScaleRange = 0.1
        e.particleScaleSpeed = -0.12
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor.white,
                UIColor(red: 0.75, green: 0.92, blue: 1, alpha: 1),
                UIColor(red: 1, green: 0.92, blue: 0.35, alpha: 1),
                UIColor(red: 1, green: 0.42, blue: 0.08, alpha: 1),
                UIColor(red: 0.85, green: 0.1, blue: 0.05, alpha: 0),
            ],
            times: [0, 0.1, 0.28, 0.55, 1]
        )
        e.particleBlendMode = .add
        e.yAcceleration = -28
        e.position = CGPoint(x: 0, y: -6)
        return e
    }

    static func makeSmokeEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.particleLifetime = 1.35
        e.particleLifetimeRange = 0.4
        e.particleSpeed = 68
        e.particleSpeedRange = 32
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.5
        e.particleAlpha = 0.62
        e.particleAlphaSpeed = -0.38
        e.particleScale = 0.42
        e.particleScaleRange = 0.18
        e.particleScaleSpeed = 0.28
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor(white: 0.95, alpha: 0.55),
                UIColor(white: 0.65, alpha: 0.4),
                UIColor(white: 0.4, alpha: 0.22),
                UIColor(white: 0.28, alpha: 0),
            ],
            times: [0, 0.22, 0.6, 1]
        )
        e.particleBlendMode = .alpha
        e.yAcceleration = -16
        e.position = CGPoint(x: 0, y: -16)
        return e
    }

    static func makeSparkEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.particleLifetime = 0.18
        e.particleLifetimeRange = 0.08
        e.particleSpeed = 140
        e.particleSpeedRange = 80
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.6
        e.particleAlpha = 1
        e.particleAlphaSpeed = -5
        e.particleScale = 0.08
        e.particleScaleRange = 0.04
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor.white,
                UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1),
                UIColor(red: 1, green: 0.35, blue: 0.1, alpha: 0),
            ],
            times: [0, 0.35, 1]
        )
        e.particleBlendMode = .add
        e.yAcceleration = 40
        e.position = CGPoint(x: 0, y: -4)
        return e
    }

    static func makeFallSparkEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.particleLifetime = 0.45
        e.particleLifetimeRange = 0.2
        e.particleSpeed = 75
        e.particleSpeedRange = 45
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.85
        e.particleAlpha = 0.9
        e.particleAlphaSpeed = -2
        e.particleScale = 0.15
        e.particleScaleRange = 0.08
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1),
                UIColor(red: 0.9, green: 0.2, blue: 0.1, alpha: 0.6),
                UIColor(red: 0.35, green: 0.1, blue: 0.08, alpha: 0),
            ],
            times: [0, 0.4, 1]
        )
        e.particleBlendMode = .add
        e.yAcceleration = -35
        return e
    }

    static func makeWreckSmokeEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.particleLifetime = 2.4
        e.particleLifetimeRange = 0.8
        e.particleSpeed = 22
        e.particleSpeedRange = 14
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.9
        e.particleAlpha = 0.45
        e.particleAlphaSpeed = -0.18
        e.particleScale = 0.55
        e.particleScaleRange = 0.25
        e.particleScaleSpeed = 0.35
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor(white: 0.55, alpha: 0.4),
                UIColor(white: 0.35, alpha: 0.28),
                UIColor(white: 0.22, alpha: 0.12),
                UIColor(white: 0.18, alpha: 0),
            ],
            times: [0, 0.3, 0.7, 1]
        )
        e.particleBlendMode = .alpha
        e.yAcceleration = -8
        e.position = CGPoint(x: 0, y: -8)
        return e
    }

    static func makeImpactBurst() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.numParticlesToEmit = 160
        e.particleLifetime = 0.75
        e.particleLifetimeRange = 0.3
        e.particleSpeed = 220
        e.particleSpeedRange = 140
        e.emissionAngle = 0
        e.emissionAngleRange = .pi * 2
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1.4
        e.particleScale = 0.45
        e.particleScaleRange = 0.28
        e.particleScaleSpeed = -0.22
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor.white,
                UIColor(red: 1, green: 0.8, blue: 0.25, alpha: 1),
                UIColor(red: 0.95, green: 0.22, blue: 0.1, alpha: 0.85),
                UIColor(red: 0.35, green: 0.08, blue: 0.06, alpha: 0),
            ],
            times: [0, 0.18, 0.5, 1]
        )
        e.particleBlendMode = .add
        e.yAcceleration = -70
        return e
    }

    static func makeImpactSmokePlume() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.numParticlesToEmit = 55
        e.particleLifetime = 1.6
        e.particleLifetimeRange = 0.5
        e.particleSpeed = 95
        e.particleSpeedRange = 50
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 1.1
        e.particleAlpha = 0.7
        e.particleAlphaSpeed = -0.35
        e.particleScale = 0.65
        e.particleScaleRange = 0.3
        e.particleScaleSpeed = 0.4
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor(white: 0.7, alpha: 0.55),
                UIColor(white: 0.4, alpha: 0.35),
                UIColor(white: 0.25, alpha: 0),
            ],
            times: [0, 0.4, 1]
        )
        e.particleBlendMode = .alpha
        e.yAcceleration = -25
        return e
    }

    static func makeDebrisBurst() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.numParticlesToEmit = 40
        e.particleLifetime = 1.1
        e.particleLifetimeRange = 0.4
        e.particleSpeed = 130
        e.particleSpeedRange = 90
        e.emissionAngle = 0
        e.emissionAngleRange = .pi * 2
        e.particleAlpha = 0.95
        e.particleAlphaSpeed = -0.85
        e.particleScale = 0.12
        e.particleScaleRange = 0.06
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor(red: 0.75, green: 0.78, blue: 0.85, alpha: 1),
                UIColor(red: 0.45, green: 0.48, blue: 0.55, alpha: 0.8),
                UIColor(red: 0.25, green: 0.26, blue: 0.3, alpha: 0),
            ],
            times: [0, 0.5, 1]
        )
        e.particleBlendMode = .alpha
        e.yAcceleration = 120
        e.xAcceleration = 0
        return e
    }
}
