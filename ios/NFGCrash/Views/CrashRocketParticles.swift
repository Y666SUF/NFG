import SpriteKit
import SwiftUI
import UIKit

// MARK: - Exhaust (fire + smoke while flying)

struct RocketExhaustParticlesView: UIViewRepresentable {
    var rocketPosition: CGPoint
    var exhaustAngleRadians: CGFloat
    var isActive: Bool

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.isUserInteractionEnabled = false
        view.isOpaque = false
        let scene = RocketParticleScene(size: CGSize(width: 320, height: 160))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
        view.presentScene(scene)
        context.coordinator.scene = scene
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        guard let scene = context.coordinator.scene else { return }
        scene.size = view.bounds.size
        scene.updateExhaust(
            at: rocketPosition,
            angle: exhaustAngleRadians,
            active: isActive
        )
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
        let view = SKView()
        view.backgroundColor = .clear
        view.allowsTransparency = true
        view.isUserInteractionEnabled = false
        view.isOpaque = false
        let scene = RocketParticleScene(size: CGSize(width: 320, height: 160))
        scene.scaleMode = .resizeFill
        scene.backgroundColor = .clear
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

// MARK: - SpriteKit scene

final class RocketParticleScene: SKScene {
    private let exhaustRoot = SKNode()
    private let fireEmitter = RocketParticleFactory.makeFireEmitter()
    private let smokeEmitter = RocketParticleFactory.makeSmokeEmitter()
    private var exhaustActive = false

    override init(size: CGSize) {
        super.init(size: size)
        addChild(exhaustRoot)
        exhaustRoot.addChild(smokeEmitter)
        exhaustRoot.addChild(fireEmitter)
        exhaustRoot.isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateExhaust(at point: CGPoint, angle: CGFloat, active: Bool) {
        exhaustActive = active
        exhaustRoot.isHidden = !active
        guard active, size.width > 1, size.height > 1 else {
            fireEmitter.particleBirthRate = 0
            smokeEmitter.particleBirthRate = 0
            return
        }
        let sk = Self.skPoint(from: point, sceneSize: size)
        exhaustRoot.position = sk
        exhaustRoot.zRotation = angle + .pi
        fireEmitter.particleBirthRate = 140
        smokeEmitter.particleBirthRate = 55
        fireEmitter.targetNode = self
        smokeEmitter.targetNode = self
    }

    func playImpact(at point: CGPoint) {
        guard size.width > 1, size.height > 1 else { return }
        let sk = Self.skPoint(from: point, sceneSize: size)
        let burst = RocketParticleFactory.makeImpactBurst()
        burst.position = sk
        addChild(burst)
        burst.run(.sequence([
            .wait(forDuration: 1.4),
            .removeFromParent(),
        ]))
    }

    override func update(_ currentTime: TimeInterval) {
        if !exhaustActive {
            fireEmitter.particleBirthRate = 0
            smokeEmitter.particleBirthRate = 0
        }
    }

    private static func skPoint(from viewPoint: CGPoint, sceneSize: CGSize) -> CGPoint {
        CGPoint(x: viewPoint.x, y: sceneSize.height - viewPoint.y)
    }
}

// MARK: - Emitter presets

private enum RocketParticleFactory {
    static let softTexture: SKTexture = {
        let d: CGFloat = 24
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: d, height: d))
        let img = renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: d, height: d)
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            ctx.cgContext.fillEllipse(in: rect.insetBy(dx: 2, dy: 2))
        }
        return SKTexture(image: img)
    }()

    static func makeFireEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.numParticlesToEmit = 0
        e.particleLifetime = 0.28
        e.particleLifetimeRange = 0.12
        e.particleSpeed = 95
        e.particleSpeedRange = 45
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.35
        e.particleAlpha = 0.95
        e.particleAlphaSpeed = -3.2
        e.particleScale = 0.22
        e.particleScaleRange = 0.08
        e.particleScaleSpeed = -0.15
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor.white,
                UIColor(red: 1, green: 0.95, blue: 0.4, alpha: 1),
                UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1),
                UIColor(red: 0.9, green: 0.15, blue: 0.05, alpha: 0),
            ],
            times: [0, 0.15, 0.45, 1]
        )
        e.particleBlendMode = .add
        e.yAcceleration = -20
        e.position = CGPoint(x: 0, y: -8)
        return e
    }

    static func makeSmokeEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.particleLifetime = 1.1
        e.particleLifetimeRange = 0.35
        e.particleSpeed = 55
        e.particleSpeedRange = 28
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.55
        e.particleAlpha = 0.55
        e.particleAlphaSpeed = -0.45
        e.particleScale = 0.35
        e.particleScaleRange = 0.15
        e.particleScaleSpeed = 0.22
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor(white: 0.92, alpha: 0.5),
                UIColor(white: 0.55, alpha: 0.35),
                UIColor(white: 0.35, alpha: 0.15),
                UIColor(white: 0.25, alpha: 0),
            ],
            times: [0, 0.25, 0.65, 1]
        )
        e.particleBlendMode = .alpha
        e.yAcceleration = -12
        e.position = CGPoint(x: 0, y: -14)
        return e
    }

    static func makeImpactBurst() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = softTexture
        e.particleBirthRate = 0
        e.numParticlesToEmit = 120
        e.particleLifetime = 0.85
        e.particleLifetimeRange = 0.35
        e.particleSpeed = 180
        e.particleSpeedRange = 120
        e.emissionAngle = 0
        e.emissionAngleRange = .pi * 2
        e.particleAlpha = 1
        e.particleAlphaSpeed = -1.2
        e.particleScale = 0.4
        e.particleScaleRange = 0.25
        e.particleScaleSpeed = -0.2
        e.particleColorBlendFactor = 1
        e.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [
                UIColor.white,
                UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 1),
                UIColor(red: 0.95, green: 0.25, blue: 0.12, alpha: 0.8),
                UIColor(red: 0.4, green: 0.1, blue: 0.08, alpha: 0),
            ],
            times: [0, 0.2, 0.55, 1]
        )
        e.particleBlendMode = .add
        e.yAcceleration = -60
        return e
    }
}
