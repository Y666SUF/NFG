import UIKit

struct VaultRunParticle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var age: CGFloat = 0
    var lifetime: CGFloat
    var size: CGFloat
    var color: UIColor
}

@MainActor
final class VaultRunVisualFXState {
    private(set) var particles: [VaultRunParticle] = []
    private var engineTrail: [(x: CGFloat, y: CGFloat)] = []
    private var milestonePulseAge: CGFloat = -1
    private let milestonePulseDuration: CGFloat = 0.65

    func reset() {
        particles.removeAll()
        engineTrail.removeAll()
        milestonePulseAge = -1
    }

    func triggerMilestone(at center: CGPoint, trail: UIColor, cockpit: UIColor) {
        milestonePulseAge = 0
        for i in 0..<18 {
            let angle = CGFloat(i) / 18 * .pi * 2
            let speed = CGFloat.random(in: 70...160)
            particles.append(VaultRunParticle(
                x: center.x,
                y: center.y,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed,
                lifetime: CGFloat.random(in: 0.35...0.65),
                size: CGFloat.random(in: 2.5...5.5),
                color: (i % 2 == 0 ? trail : cockpit).withAlphaComponent(0.9)
            ))
        }
    }

    func advanceMilestonePulse(dt: CGFloat) {
        guard milestonePulseAge >= 0 else { return }
        milestonePulseAge += dt
        if milestonePulseAge > milestonePulseDuration {
            milestonePulseAge = -1
        }
    }

    var activeMilestonePulseProgress: CGFloat? {
        guard milestonePulseAge >= 0 else { return nil }
        return min(1, milestonePulseAge / milestonePulseDuration)
    }

    func update(
        dt: CGFloat,
        shipCenter: CGPoint,
        trailColor: UIColor,
        cockpitColor: UIColor,
        trailTier: Int,
        speed: CGFloat,
        sessionActive: Bool
    ) {
        tickParticles(dt: dt)
        recordEngineTrail(shipCenter: shipCenter, tier: trailTier)
        advanceMilestonePulse(dt: dt)

        guard sessionActive else { return }

        let intensity = min(1, speed / 24) * (0.35 + CGFloat(trailTier) * 0.08)
        if CGFloat.random(in: 0...1) < intensity {
            spawnEngineSpark(at: shipCenter, trail: trailColor, tier: trailTier)
        }
        if trailTier >= 2, CGFloat.random(in: 0...1) < 0.12 + CGFloat(trailTier) * 0.02 {
            particles.append(VaultRunParticle(
                x: shipCenter.x + CGFloat.random(in: -10...10),
                y: shipCenter.y + CGFloat.random(in: 8...22),
                vx: CGFloat.random(in: -12...12),
                vy: CGFloat.random(in: 30...70),
                lifetime: 0.3,
                size: CGFloat.random(in: 1...2.5),
                color: UIColor.white.withAlphaComponent(0.22)
            ))
        }
        if trailTier >= 4, CGFloat.random(in: 0...1) < 0.08 {
            spawnAuraSparkle(at: shipCenter, color: cockpitColor)
        }
    }

    private func spawnEngineSpark(at center: CGPoint, trail: UIColor, tier: Int) {
        let spread = 6 + CGFloat(tier) * 1.2
        particles.append(VaultRunParticle(
            x: center.x + CGFloat.random(in: -spread...spread),
            y: center.y + CGFloat.random(in: 10...18),
            vx: CGFloat.random(in: -20...20),
            vy: CGFloat.random(in: 40...110),
            lifetime: CGFloat.random(in: 0.22...0.42),
            size: CGFloat.random(in: 1.8...3.8 + CGFloat(tier) * 0.2),
            color: trail.withAlphaComponent(0.75)
        ))
    }

    private func spawnAuraSparkle(at center: CGPoint, color: UIColor) {
        let angle = CGFloat.random(in: 0...(2 * .pi))
        let dist = CGFloat.random(in: 14...28)
        particles.append(VaultRunParticle(
            x: center.x + cos(angle) * dist,
            y: center.y + sin(angle) * dist,
            vx: cos(angle) * 30,
            vy: sin(angle) * 30,
            lifetime: 0.35,
            size: 2.2,
            color: color.withAlphaComponent(0.85)
        ))
    }

    private func recordEngineTrail(shipCenter: CGPoint, tier: Int) {
        guard tier >= 1 else {
            engineTrail.removeAll()
            return
        }
        let maxPoints = min(16, 6 + tier)
        if let last = engineTrail.last {
            let dx = shipCenter.x - last.x
            let dy = shipCenter.y - last.y
            if dx * dx + dy * dy < 9 { return }
        }
        engineTrail.append((shipCenter.x, shipCenter.y))
        if engineTrail.count > maxPoints {
            engineTrail.removeFirst(engineTrail.count - maxPoints)
        }
    }

    private func tickParticles(dt: CGFloat) {
        for i in particles.indices.reversed() {
            particles[i].age += dt
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            particles[i].vy += 40 * dt
            if particles[i].age >= particles[i].lifetime {
                particles.remove(at: i)
            }
        }
        if particles.count > 90 {
            particles.removeFirst(particles.count - 90)
        }
    }

    func draw(in ctx: CGContext, shipCenter: CGPoint, cosmetics: VaultRunShipCosmetics) {
        drawEngineTrail(in: ctx, cosmetics: cosmetics)
        for p in particles {
            let t = 1 - p.age / p.lifetime
            ctx.setFillColor(p.color.withAlphaComponent(p.color.cgColor.alpha * t).cgColor)
            ctx.fillEllipse(in: CGRect(x: p.x - p.size, y: p.y - p.size, width: p.size * 2, height: p.size * 2))
        }
        if let pulse = activeMilestonePulseProgress {
            VaultRunDraw.drawMilestonePulse(ctx, center: shipCenter, progress: pulse, accent: cosmetics.trail)
        }
        if cosmetics.trailTier >= 2 {
            VaultRunDraw.drawShipAura(
                ctx,
                center: shipCenter,
                tier: cosmetics.trailTier,
                trail: cosmetics.trail,
                cockpit: cosmetics.cockpit
            )
        }
    }

    private func drawEngineTrail(in ctx: CGContext, cosmetics: VaultRunShipCosmetics) {
        guard engineTrail.count >= 2, cosmetics.trailTier >= 1 else { return }
        let points = engineTrail
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for i in 1..<points.count {
            let t = CGFloat(i) / CGFloat(points.count)
            let alpha = 0.15 + t * 0.45
            ctx.setStrokeColor(cosmetics.trail.withAlphaComponent(alpha).cgColor)
            ctx.setLineWidth(2 + t * 3 + CGFloat(cosmetics.trailTier) * 0.35)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: points[i - 1].x, y: points[i - 1].y))
            ctx.addLine(to: CGPoint(x: points[i].x, y: points[i].y))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
}
