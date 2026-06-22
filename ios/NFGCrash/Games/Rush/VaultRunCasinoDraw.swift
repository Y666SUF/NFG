import SwiftUI
import UIKit

/// Casino-themed procedural art for NFG Rush — green felt runway, gold trim, gambler runner.
enum VaultRunCasinoDraw {
    private static let matrixGlyphs = ["♠", "♥", "♦", "♣", "7", "K", "A", "J", "Q", "$"]

    // MARK: - Environment

    static func drawEnvironment(
        ctx: CGContext,
        rect: CGRect,
        elapsed: CGFloat,
        scrollPhase: CGFloat
    ) {
        VaultRunDraw.fillGradient(
            ctx,
            in: rect,
            top: VaultRunTheme.feltTop,
            bottom: VaultRunTheme.feltFloor
        )

        // Velvet ceiling wash
        ctx.setFillColor(VaultRunTheme.velvetPurple.withAlphaComponent(0.28).cgColor)
        ctx.fillEllipse(in: CGRect(x: rect.width * 0.1, y: -rect.height * 0.05, width: rect.width * 0.8, height: rect.height * 0.35))

        // Spotlight cones
        for i in 0..<3 {
            let x = rect.width * (0.2 + CGFloat(i) * 0.3)
            let colors = [
                VaultRunTheme.goldTrim.withAlphaComponent(0.14).cgColor,
                UIColor.clear.cgColor,
            ] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.drawRadialGradient(
                    g,
                    startCenter: CGPoint(x: x, y: 0),
                    startRadius: 4,
                    endCenter: CGPoint(x: x, y: rect.height * 0.55),
                    endRadius: rect.width * 0.35,
                    options: []
                )
            }
        }

        drawMatrixRain(ctx: ctx, rect: rect, elapsed: elapsed)

        // Distant marquee dots
        for i in 0..<24 {
            let seed = CGFloat(i)
            let fx = VaultRunDraw.fract(sin(seed * 47.11) * 9123.77)
            let x = rect.width * fx
            let blink = 0.25 + sin(elapsed * 2.5 + seed) * 0.2
            ctx.setFillColor(VaultRunTheme.goldTrim.withAlphaComponent(blink).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: rect.height * 0.08, width: 3, height: 3))
        }
    }

    private static func drawMatrixRain(ctx: CGContext, rect: CGRect, elapsed: CGFloat) {
        let cols = 7
        let colW = rect.width / CGFloat(cols)
        let step: CGFloat = 16
        let speed: CGFloat = 42

        for col in 0..<cols {
            let x = colW * CGFloat(col) + colW * 0.5
            let seed = CGFloat(col) * 17.3
            let headY = (elapsed * speed + seed * 40).truncatingRemainder(dividingBy: rect.height + step * 5 + 30)

            for trail in 0..<4 {
                let y = headY - CGFloat(trail) * step
                guard y > -10, y < rect.height * 0.75 else { continue }
                let alpha = 0.04 + (1 - CGFloat(trail) / 4) * 0.08
                let glyph = matrixGlyphs[(col + trail) % matrixGlyphs.count]
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                    .foregroundColor: VaultRunTheme.chipGold.withAlphaComponent(alpha),
                ]
                (glyph as NSString).draw(at: CGPoint(x: x - 4, y: y), withAttributes: attrs)
            }
        }
    }

    // MARK: - Corridor (felt runway)

    static func drawCasinoCorridor(
        ctx: CGContext,
        layout: VaultRunPerspectiveLayout,
        scrollPhase: CGFloat
    ) {
        let edge = VaultRunPerspectiveLayout.trackEdgeNorm
        let bands = 14

        for i in 0..<bands {
            let t0 = CGFloat(i) / CGFloat(bands)
            let t1 = CGFloat(i + 1) / CGFloat(bands)
            let phase = (t0 + scrollPhase * 0.22).truncatingRemainder(dividingBy: 1)

            let topL = layout.pointAtNorm(-edge, depth: t0)
            let topR = layout.pointAtNorm(edge, depth: t0)
            let botL = layout.pointAtNorm(-edge, depth: t1)
            let botR = layout.pointAtNorm(edge, depth: t1)

            let stripe = Int(phase * 14) % 2 == 0
            let felt = stripe ? VaultRunTheme.feltLaneLight : VaultRunTheme.feltLaneDark
            ctx.setFillColor(felt.withAlphaComponent(0.55 + phase * 0.15).cgColor)
            ctx.beginPath()
            ctx.move(to: topL)
            ctx.addLine(to: topR)
            ctx.addLine(to: botR)
            ctx.addLine(to: botL)
            ctx.closePath()
            ctx.fillPath()

            // Chip flecks on runway
            if Int(phase * 14) % 3 == 0, t1 > 0.15, t1 < 0.9 {
                let chipCenter = layout.pointAtNorm(
                    sin(phase * 8) * 0.4,
                    depth: (t0 + t1) * 0.5
                )
                drawMiniChip(ctx: ctx, center: chipCenter, radius: layout.scale(depth: t1) * 3, color: VaultRunTheme.chipGold)
            }
        }

        // Gold lane dividers
        ctx.setStrokeColor(VaultRunTheme.goldTrim.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(1.4)
        ctx.setLineDash(phase: scrollPhase * 14, lengths: [6, 8])
        for dividerNorm in VaultRunPerspectiveLayout.laneDividerNorms {
            let top = layout.pointAtNorm(dividerNorm, depth: 0)
            let bottom = layout.pointAtNorm(dividerNorm, depth: 1)
            ctx.beginPath()
            ctx.move(to: top)
            ctx.addLine(to: bottom)
            ctx.strokePath()
        }
        ctx.setLineDash(phase: 0, lengths: [])

        // Edge rails — gold trim
        ctx.setStrokeColor(VaultRunTheme.goldTrim.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(2.5)
        for railNorm: CGFloat in [-edge, edge] {
            let top = layout.pointAtNorm(railNorm, depth: 0)
            let bottom = layout.pointAtNorm(railNorm, depth: 1)
            ctx.beginPath()
            ctx.move(to: top)
            ctx.addLine(to: bottom)
            ctx.strokePath()
        }

        // Red carpet accent strips inside rails
        ctx.setStrokeColor(VaultRunTheme.hazardRed.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(1)
        for inset: CGFloat in [-0.92, 0.92] {
            let top = layout.pointAtNorm(inset * edge, depth: 0.05)
            let bottom = layout.pointAtNorm(inset * edge, depth: 0.95)
            ctx.beginPath()
            ctx.move(to: top)
            ctx.addLine(to: bottom)
            ctx.strokePath()
        }
    }

    static func drawFloatingChips(
        ctx: CGContext,
        layout: VaultRunPerspectiveLayout,
        phase: CGFloat
    ) {
        for side: CGFloat in [-1, 1] {
            for i in 0..<4 {
                let depth = 0.1 + CGFloat(i) * 0.18
                let wobble = sin(phase + side * 2 + CGFloat(i)) * 0.08
                let p = layout.pointAtNorm(side * VaultRunPerspectiveLayout.trackEdgeNorm * 1.4 + wobble, depth: depth)
                let r = layout.scale(depth: depth) * (10 + CGFloat(i) * 2)
                let chipColor: UIColor = i % 2 == 0 ? VaultRunTheme.chipRed : VaultRunTheme.chipGold
                drawMiniChip(ctx: ctx, center: p, radius: r, color: chipColor)
            }
        }
    }

  // MARK: - Obstacles

    static func drawSlotBust(
        ctx: CGContext,
        center: CGPoint,
        laneWidth: CGFloat,
        scale: CGFloat
    ) {
        let w = laneWidth * 0.82
        let h = 38 * scale
        let body = CGRect(x: center.x - w * 0.5, y: center.y - h * 0.5, width: w, height: h)

        // Slot machine body
        ctx.setFillColor(VaultRunTheme.hazardRed.cgColor)
        fillPath(ctx, UIBezierPath(roundedRect: body, cornerRadius: 6 * scale))

        ctx.setFillColor(VaultRunTheme.goldTrim.withAlphaComponent(0.85).cgColor)
        ctx.fill(CGRect(x: body.minX + w * 0.12, y: body.minY + h * 0.15, width: w * 0.76, height: h * 0.35))

        // BUST text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: max(8, 10 * scale), weight: .black),
            .foregroundColor: UIColor.white,
        ]
        ("BUST" as NSString).draw(
            at: CGPoint(x: center.x - w * 0.22, y: body.minY + h * 0.2),
            withAttributes: attrs
        )

        ctx.setFillColor(VaultRunTheme.chipGold.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - 4 * scale, y: body.maxY - 8 * scale, width: 8 * scale, height: 8 * scale))
    }

    static func drawCardRow(
        ctx: CGContext,
        center: CGPoint,
        laneWidth: CGFloat,
        scale: CGFloat
    ) {
        let rowH = 18 * scale
        let row = CGRect(x: center.x - laneWidth * 0.52, y: center.y - rowH * 0.5, width: laneWidth * 1.04, height: rowH)
        ctx.setFillColor(VaultRunTheme.hazardOrange.cgColor)
        fillPath(ctx, UIBezierPath(roundedRect: row, cornerRadius: rowH * 0.3))

        for i in 0..<5 {
            let cardW = laneWidth * 0.16
            let cardH = rowH * 0.75
            let cx = row.minX + laneWidth * (0.08 + CGFloat(i) * 0.18)
            let card = CGRect(x: cx, y: center.y - cardH * 0.5, width: cardW, height: cardH)
            ctx.setFillColor(UIColor.white.cgColor)
            fillPath(ctx, UIBezierPath(roundedRect: card, cornerRadius: 2 * scale))
            let suit = i % 2 == 0 ? "♥" : "♠"
            let suitAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(7, 9 * scale), weight: .bold),
                .foregroundColor: i % 2 == 0 ? VaultRunTheme.hazardRed : UIColor.black,
            ]
            (suit as NSString).draw(at: CGPoint(x: card.midX - 4 * scale, y: card.midY - 5 * scale), withAttributes: suitAttrs)
        }
    }

    static func drawTableArch(
        ctx: CGContext,
        center: CGPoint,
        laneWidth: CGFloat,
        scale: CGFloat
    ) {
        let archW = laneWidth * 1.1
        let archH = 50 * scale
        let outer = CGRect(x: center.x - archW * 0.5, y: center.y - archH * 0.5, width: archW, height: archH)
        let holeW = laneWidth * 0.4
        let holeH = archH * 0.38
        let hole = CGRect(x: center.x - holeW * 0.5, y: center.y - holeH * 0.5, width: holeW, height: holeH)

        let path = UIBezierPath(roundedRect: outer, cornerRadius: archH * 0.2)
        path.append(UIBezierPath(ovalIn: hole))
        path.usesEvenOddFillRule = true
        ctx.setFillColor(VaultRunTheme.hazardPurple.cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()

        // Gold trim on arch
        ctx.setStrokeColor(VaultRunTheme.goldTrim.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(2 * scale)
        strokePath(ctx, UIBezierPath(roundedRect: outer.insetBy(dx: 2 * scale, dy: 2 * scale), cornerRadius: archH * 0.18), width: 2 * scale)

        ctx.setFillColor(VaultRunTheme.feltFloor.withAlphaComponent(0.9).cgColor)
        ctx.fillEllipse(in: hole.insetBy(dx: 3 * scale, dy: 3 * scale))
    }

    // MARK: - Runner (Temple Run chase view)

    static func drawRunner(
        ctx: CGContext,
        center: CGPoint,
        scale: CGFloat,
        action: VaultRunEngine.PlayerAction,
        jumpLift: CGFloat,
        cosmetics: VaultRunShipCosmetics,
        runPhase: CGFloat,
        laneLean: CGFloat
    ) {
        var y = center.y
        var s = scale
        let lean = laneLean * 8 * scale

        switch action {
        case .running:
            y -= jumpLift * 14 * scale
            y -= sin(runPhase * .pi * 2) * 2 * scale
        case .jumping:
            y -= jumpLift * 22 * scale
        case .sliding:
            s *= 0.45
            y += 6 * scale
        }

        VaultRunDraw.drawShadowEllipse(ctx, center: CGPoint(x: center.x, y: y + 14 * s), width: 22 * s, height: 8 * s, alpha: 0.4)

        ctx.saveGState()
        ctx.translateBy(x: center.x, y: y)
        ctx.rotate(by: lean * 0.04)

        let vestColor = cosmetics.hull
        let accentColor = cosmetics.cockpit
        let trailColor = cosmetics.trail

        // Chip trail behind runner
        drawRunnerTrail(ctx: ctx, scale: s, trail: trailColor, tier: cosmetics.trailTier)

        switch action {
        case .sliding:
            drawSlidingRunner(ctx: ctx, scale: s, vest: vestColor, accent: accentColor)
        default:
            drawRunningRunner(ctx: ctx, scale: s, vest: vestColor, accent: accentColor, action: action, runPhase: runPhase)
        }

        ctx.restoreGState()
    }

    private static func drawRunnerTrail(
        ctx: CGContext,
        scale: CGFloat,
        trail: UIColor,
        tier: Int
    ) {
        let count = 2 + tier
        for i in 0..<count {
            let fi = CGFloat(i)
            let py = 10 * scale + fi * 4 * scale
            let r = (3 + CGFloat(tier) * 0.3 - fi * 0.3) * scale
            ctx.setFillColor(trail.withAlphaComponent(0.5 - fi * 0.08).cgColor)
            ctx.fillEllipse(in: CGRect(x: -r, y: py - r, width: r * 2, height: r * 2))
        }
    }

    private static func drawRunningRunner(
        ctx: CGContext,
        scale: CGFloat,
        vest: UIColor,
        accent: UIColor,
        action: VaultRunEngine.PlayerAction,
        runPhase: CGFloat
    ) {
        let legSwing = sin(runPhase * .pi * 2) * 6 * scale

        // Legs
        for side: CGFloat in [-1, 1] {
            let swing = side * legSwing
            let legPath = UIBezierPath()
            legPath.move(to: CGPoint(x: side * 3 * scale, y: 2 * scale))
            legPath.addLine(to: CGPoint(x: side * 4 * scale + swing, y: 14 * scale))
            ctx.setStrokeColor(UIColor(red: 0.15, green: 0.12, blue: 0.1, alpha: 1).cgColor)
            ctx.setLineWidth(3.5 * scale)
            ctx.setLineCap(.round)
            ctx.addPath(legPath.cgPath)
            ctx.strokePath()
        }

        // Torso / vest
        let torso = CGRect(x: -7 * scale, y: -10 * scale, width: 14 * scale, height: 14 * scale)
        ctx.setFillColor(vest.cgColor)
        fillPath(ctx, UIBezierPath(roundedRect: torso, cornerRadius: 4 * scale))

        // Gold trim on vest
        ctx.setStrokeColor(VaultRunTheme.goldTrim.withAlphaComponent(0.7).cgColor)
        ctx.setLineWidth(1 * scale)
        strokePath(ctx, UIBezierPath(roundedRect: torso.insetBy(dx: 1, dy: 1), cornerRadius: 3 * scale), width: 1 * scale)

        // Arms
        for side: CGFloat in [-1, 1] {
            let armSwing = -side * legSwing * 0.6
            ctx.setStrokeColor(vest.withAlphaComponent(0.9).cgColor)
            ctx.setLineWidth(2.5 * scale)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: side * 6 * scale, y: -6 * scale))
            ctx.addLine(to: CGPoint(x: side * 9 * scale + armSwing, y: 2 * scale))
            ctx.strokePath()
        }

        // Head
        let headR = 5.5 * scale
        ctx.setFillColor(UIColor(red: 0.92, green: 0.78, blue: 0.62, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: -headR, y: -18 * scale, width: headR * 2, height: headR * 2))

        // Cap / accent
        ctx.setFillColor(accent.cgColor)
        ctx.fill(CGRect(x: -6 * scale, y: -20 * scale, width: 12 * scale, height: 4 * scale))

        if action == .jumping {
            ctx.setFillColor(accent.withAlphaComponent(0.25).cgColor)
            ctx.fillEllipse(in: CGRect(x: -12 * scale, y: 4 * scale, width: 24 * scale, height: 10 * scale))
        }
    }

    private static func drawSlidingRunner(
        ctx: CGContext,
        scale: CGFloat,
        vest: UIColor,
        accent: UIColor
    ) {
        let body = CGRect(x: -12 * scale, y: -4 * scale, width: 24 * scale, height: 10 * scale)
        ctx.setFillColor(vest.cgColor)
        fillPath(ctx, UIBezierPath(roundedRect: body, cornerRadius: 5 * scale))

        ctx.setFillColor(UIColor(red: 0.92, green: 0.78, blue: 0.62, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: 8 * scale, y: -8 * scale, width: 7 * scale, height: 7 * scale))

        ctx.setFillColor(accent.cgColor)
        ctx.fill(CGRect(x: 10 * scale, y: -9 * scale, width: 5 * scale, height: 3 * scale))
    }

    static func runnerPreviewPath(style: String, in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY + 2
        let s = min(rect.width, rect.height) / 34
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: cx - 7 * s, y: cy - 8 * s, width: 14 * s, height: 14 * s),
            cornerSize: CGSize(width: 4 * s, height: 4 * s)
        )
        path.addEllipse(in: CGRect(x: cx - 5 * s, y: cy - 18 * s, width: 10 * s, height: 10 * s))
        if style == "fighter" || style == "inferno" {
            path.move(to: CGPoint(x: cx - 10 * s, y: cy - 2 * s))
            path.addLine(to: CGPoint(x: cx - 14 * s, y: cy + 4 * s))
            path.move(to: CGPoint(x: cx + 10 * s, y: cy - 2 * s))
            path.addLine(to: CGPoint(x: cx + 14 * s, y: cy + 4 * s))
        }
        return path
    }

    // MARK: - Helpers

    private static func fillPath(_ ctx: CGContext, _ path: UIBezierPath) {
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }

    private static func strokePath(_ ctx: CGContext, _ path: UIBezierPath, width: CGFloat) {
        ctx.setLineWidth(width)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
    }

    private static func drawMiniChip(ctx: CGContext, center: CGPoint, radius: CGFloat, color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.setStrokeColor(VaultRunTheme.goldTrim.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(max(0.5, radius * 0.15))
        ctx.strokeEllipse(in: CGRect(x: center.x - radius * 0.85, y: center.y - radius * 0.85, width: radius * 1.7, height: radius * 1.7))
    }
}
