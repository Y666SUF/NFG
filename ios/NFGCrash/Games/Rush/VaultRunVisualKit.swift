import SwiftUI
import UIKit

/// Casino runway palette and procedural drawing helpers (no external assets).
enum VaultRunTheme {
    static let feltTop = UIColor(red: 0.04, green: 0.09, blue: 0.07, alpha: 1)
    static let feltFloor = UIColor(red: 0.02, green: 0.05, blue: 0.06, alpha: 1)
    static let feltLaneLight = UIColor(red: 0.08, green: 0.22, blue: 0.16, alpha: 1)
    static let feltLaneDark = UIColor(red: 0.05, green: 0.14, blue: 0.11, alpha: 1)
    static let velvetPurple = UIColor(red: 0.22, green: 0.06, blue: 0.18, alpha: 1)
    static let chipGold = UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1)
    static let chipRed = UIColor(red: 0.85, green: 0.15, blue: 0.18, alpha: 1)
    static let goldTrim = UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1)
    static let starWhite = UIColor(red: 0.98, green: 0.94, blue: 0.85, alpha: 1)
    // Legacy aliases used by obstacle drawing
    static let spaceTop = feltTop
    static let spaceFloor = feltFloor
    static let nebulaPurple = velvetPurple
    static let nebulaCyan = UIColor(red: 0.1, green: 0.35, blue: 0.22, alpha: 1)
    static let sunGlow = chipGold
    static let stoneLight = UIColor(red: 0.58, green: 0.54, blue: 0.5, alpha: 1)
    static let stoneMid = UIColor(red: 0.42, green: 0.38, blue: 0.34, alpha: 1)
    static let stoneDark = UIColor(red: 0.24, green: 0.22, blue: 0.2, alpha: 1)
    static let moss = UIColor(red: 0.12, green: 0.42, blue: 0.28, alpha: 1)
    static let fireBar = UIColor(red: 0.95, green: 0.42, blue: 0.12, alpha: 1)
    static let woodBeam = UIColor(red: 0.45, green: 0.28, blue: 0.14, alpha: 1)
    static let asteroidRock = UIColor(red: 0.48, green: 0.42, blue: 0.38, alpha: 1)
    static let asteroidDark = UIColor(red: 0.26, green: 0.22, blue: 0.2, alpha: 1)
    static let shipHull = UIColor(red: 0.12, green: 0.45, blue: 0.32, alpha: 1)
    static let shipHullDark = UIColor(red: 0.08, green: 0.28, blue: 0.2, alpha: 1)
    static let shipCockpit = UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1)
    static let engineGlow = UIColor(red: 0.95, green: 0.78, blue: 0.2, alpha: 1)
    static let engineCore = UIColor(red: 1, green: 0.92, blue: 0.55, alpha: 1)
    static let laneGlow = UIColor(red: 0.15, green: 0.55, blue: 0.38, alpha: 1)
    static let debrisField = UIColor(red: 0.95, green: 0.55, blue: 0.15, alpha: 1)
    static let hazardRed = UIColor(red: 0.92, green: 0.22, blue: 0.2, alpha: 1)
    static let hazardOrange = UIColor(red: 1, green: 0.62, blue: 0.18, alpha: 1)
    static let hazardPurple = UIColor(red: 0.45, green: 0.18, blue: 0.55, alpha: 1)
    static let shadow = UIColor(white: 0, alpha: 0.35)

    static let accentOrange = Color(red: 0.95, green: 0.42, blue: 0.18)
    static let accentGold = Color(red: 0.95, green: 0.78, blue: 0.2)
    static let accentJade = Color(red: 0.22, green: 0.72, blue: 0.48)
    static let panelStone = Color(red: 0.04, green: 0.08, blue: 0.06)
}

struct VaultRunShipCosmetics {
    var hull: UIColor
    var cockpit: UIColor
    var trail: UIColor
    var style: String
    var trailTier: Int
    var shipId: String

    static let `default` = VaultRunShipCosmetics(
        hull: VaultRunTheme.shipHull,
        cockpit: VaultRunTheme.shipCockpit,
        trail: VaultRunTheme.engineGlow,
        style: "scout",
        trailTier: 0,
        shipId: VaultRunShopCatalog.defaultShipId
    )

    static func from(shipId: String, hullHex: String, cockpitHex: String, trailHex: String, style: String) -> VaultRunShipCosmetics {
        VaultRunShipCosmetics(
            hull: UIColor.vaultRunHex(hullHex) ?? VaultRunTheme.shipHull,
            cockpit: UIColor.vaultRunHex(cockpitHex) ?? VaultRunTheme.shipCockpit,
            trail: UIColor.vaultRunHex(trailHex) ?? VaultRunTheme.engineGlow,
            style: style,
            trailTier: VaultRunShopCatalog.trailTier(for: shipId),
            shipId: shipId
        )
    }
}

enum VaultRunDraw {
    static func fillGradient(
        _ ctx: CGContext,
        in rect: CGRect,
        top: UIColor,
        bottom: UIColor
    ) {
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let g = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) else { return }
        ctx.drawLinearGradient(
            g,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
    }

    static func drawShadowEllipse(
        _ ctx: CGContext,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        alpha: CGFloat = 0.35
    ) {
        let rect = CGRect(x: center.x - width * 0.5, y: center.y - height * 0.5, width: width, height: height)
        ctx.setFillColor(UIColor(white: 0, alpha: alpha).cgColor)
        ctx.fillEllipse(in: rect)
    }

    static func fract(_ x: CGFloat) -> CGFloat {
        x - floor(x)
    }

    static func drawStar(
        _ ctx: CGContext,
        at point: CGPoint,
        radius: CGFloat,
        alpha: CGFloat
    ) {
        ctx.setFillColor(VaultRunTheme.starWhite.withAlphaComponent(alpha).cgColor)
        ctx.fillEllipse(in: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
    }

    /// Background scenery rocks (neutral gray).
    static func drawAsteroidChunk(
        _ ctx: CGContext,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        seed: CGFloat = 0
    ) {
        drawColoredRockMass(
            ctx,
            center: center,
            width: width,
            height: height,
            seed: seed,
            fill: VaultRunTheme.asteroidRock,
            shade: VaultRunTheme.asteroidDark,
            includeCraters: true
        )
    }

    private static func shadeColor(_ base: UIColor, by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(
            red: max(0, r - amount),
            green: max(0, g - amount),
            blue: max(0, b - amount),
            alpha: a
        )
    }

    private static func drawColoredRockMass(
        _ ctx: CGContext,
        center: CGPoint,
        width: CGFloat,
        height: CGFloat,
        seed: CGFloat,
        fill: UIColor,
        shade: UIColor,
        includeCraters: Bool = false
    ) {
        let wobble = sin(seed * 4.1) * 0.1
        let rect = CGRect(x: center.x - width * 0.5, y: center.y - height * 0.5, width: width, height: height)
        let radius = min(width, height) * (0.2 + wobble)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        ctx.setFillColor(fill.cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()

        let panel = CGRect(
            x: rect.minX + width * 0.12,
            y: rect.minY + height * 0.18,
            width: width * 0.42,
            height: height * 0.22
        )
        ctx.setFillColor(shade.withAlphaComponent(0.42).cgColor)
        ctx.addPath(UIBezierPath(roundedRect: panel, cornerRadius: radius * 0.45).cgPath)
        ctx.fillPath()

        guard includeCraters else { return }
        for i in 0..<2 {
            let fi = CGFloat(i)
            let craterR = width * (0.07 + fract(seed + fi) * 0.05)
            let cx = center.x + (fract(seed * 1.7 + fi) - 0.5) * width * 0.42
            let cy = center.y + (fract(seed * 2.3 + fi) - 0.5) * height * 0.35
            ctx.setFillColor(shade.withAlphaComponent(0.5).cgColor)
            ctx.fillEllipse(in: CGRect(x: cx - craterR, y: cy - craterR, width: craterR * 2, height: craterR * 2))
        }
    }

    /// Lane-blocking asteroid — solid red body (dodge).
    static func drawAsteroidObstacle(
        _ ctx: CGContext,
        center: CGPoint,
        laneWidth: CGFloat,
        scale: CGFloat,
        seed: CGFloat
    ) {
        let w = laneWidth * 0.9
        let h = 40 * scale
        drawColoredRockMass(
            ctx,
            center: center,
            width: w,
            height: h,
            seed: seed,
            fill: VaultRunTheme.hazardRed,
            shade: shadeColor(VaultRunTheme.hazardRed, by: 0.22)
        )
    }

    /// Low debris belt — solid orange field (boost up).
    static func drawDebrisBelt(
        _ ctx: CGContext,
        center: CGPoint,
        laneWidth: CGFloat,
        scale: CGFloat
    ) {
        let beltH = 20 * scale
        let belt = CGRect(x: center.x - laneWidth * 0.54, y: center.y - beltH * 0.5, width: laneWidth * 1.08, height: beltH)
        ctx.setFillColor(VaultRunTheme.hazardOrange.cgColor)
        ctx.addPath(UIBezierPath(roundedRect: belt, cornerRadius: beltH * 0.35).cgPath)
        ctx.fillPath()

        let shade = shadeColor(VaultRunTheme.hazardOrange, by: 0.18)
        ctx.setFillColor(shade.withAlphaComponent(0.55).cgColor)
        ctx.fill(CGRect(x: belt.minX + belt.width * 0.08, y: belt.midY - beltH * 0.14, width: belt.width * 0.84, height: beltH * 0.22))

        for i in 0..<6 {
            let fi = CGFloat(i)
            let rockW = laneWidth * (0.1 + fract(fi * 1.9) * 0.08)
            let rockH = rockW * 0.7
            let rx = belt.minX + belt.width * (0.07 + fi * 0.15)
            let ry = belt.midY - rockH * 0.5
            drawColoredRockMass(
                ctx,
                center: CGPoint(x: rx + rockW * 0.5, y: ry + rockH * 0.5),
                width: rockW,
                height: rockH,
                seed: fi + 2,
                fill: shadeColor(VaultRunTheme.hazardOrange, by: 0.08),
                shade: shadeColor(VaultRunTheme.hazardOrange, by: 0.28)
            )
        }
    }

    /// Rock tunnel — solid purple mass with fly-through hole (shrink down).
    static func drawRockTunnel(
        _ ctx: CGContext,
        center: CGPoint,
        laneWidth: CGFloat,
        scale: CGFloat
    ) {
        let rockW = laneWidth * 1.15
        let rockH = 52 * scale
        let outer = CGRect(x: center.x - rockW * 0.5, y: center.y - rockH * 0.5, width: rockW, height: rockH)
        let holeW = laneWidth * 0.38
        let holeH = rockH * 0.42
        let hole = CGRect(x: center.x - holeW * 0.5, y: center.y - holeH * 0.5, width: holeW, height: holeH)

        let rockPath = UIBezierPath(roundedRect: outer, cornerRadius: rockH * 0.18)
        rockPath.append(UIBezierPath(ovalIn: hole))
        rockPath.usesEvenOddFillRule = true
        ctx.setFillColor(VaultRunTheme.hazardPurple.cgColor)
        ctx.addPath(rockPath.cgPath)
        ctx.fillPath()

        let shade = shadeColor(VaultRunTheme.hazardPurple, by: 0.2)
        for corner: (CGFloat, CGFloat, CGFloat, CGFloat) in [
            (-0.34, -0.28, 0.28, 0.2),
            (0.06, -0.3, 0.34, 0.18),
            (-0.34, 0.22, 0.3, 0.2),
            (0.08, 0.2, 0.32, 0.18),
        ] {
            let panel = CGRect(
                x: center.x + rockW * corner.0,
                y: center.y + rockH * corner.1,
                width: rockW * corner.2,
                height: rockH * corner.3
            )
            ctx.setFillColor(shade.withAlphaComponent(0.45).cgColor)
            ctx.addPath(UIBezierPath(roundedRect: panel, cornerRadius: 4 * scale).cgPath)
            ctx.fillPath()
        }

        ctx.setFillColor(VaultRunTheme.spaceFloor.withAlphaComponent(0.95).cgColor)
        ctx.fillEllipse(in: hole.insetBy(dx: 3 * scale, dy: 3 * scale))
    }

    static func drawEngineTrail(
        _ ctx: CGContext,
        center: CGPoint,
        tailY: CGFloat,
        scale: CGFloat,
        cosmetics: VaultRunShipCosmetics,
        phase: CGFloat
    ) {
        let particleCount = 3 + cosmetics.trailTier
        for i in 0..<particleCount {
            let fi = CGFloat(i)
            let spread = sin(phase * 3 + fi * 1.7) * 4 * scale
            let py = tailY + 8 * scale + fi * 5 * scale
            let px = center.x + spread
            let tier = CGFloat(cosmetics.trailTier)
            let r = (3 + tier * 0.35 - fi * 0.25) * scale
            let alpha = 0.55 - fi * 0.08 + tier * 0.04
            ctx.setFillColor(cosmetics.trail.withAlphaComponent(alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2))
        }
        if cosmetics.trailTier >= 3 {
            ctx.setFillColor(cosmetics.trail.withAlphaComponent(0.2).cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - 14 * scale, y: tailY, width: 28 * scale, height: 20 * scale))
        }
    }

    /// Chase-view spaceship — layered hulls per hangar style (not simple triangles).
    static func drawSpaceship(
        _ ctx: CGContext,
        center: CGPoint,
        scale: CGFloat,
        action: VaultRunEngine.PlayerAction,
        jumpLift: CGFloat,
        cosmetics: VaultRunShipCosmetics,
        phase: CGFloat = 0
    ) {
        let frame = shipFrame(
            center: center,
            scale: scale,
            action: action,
            jumpLift: jumpLift,
            style: cosmetics.style
        )
        drawEngineTrail(ctx, center: center, tailY: frame.tailY, scale: frame.s, cosmetics: cosmetics, phase: phase)
        drawShipFlames(ctx, frame: frame, action: action, cosmetics: cosmetics)

        switch cosmetics.style {
        case "fighter":
            drawFighterHull(ctx, frame: frame, cosmetics: cosmetics)
        case "interceptor":
            drawInterceptorHull(ctx, frame: frame, cosmetics: cosmetics)
        case "phantom":
            drawPhantomHull(ctx, frame: frame, cosmetics: cosmetics)
        case "inferno":
            drawInfernoHull(ctx, frame: frame, cosmetics: cosmetics)
        default:
            drawScoutHull(ctx, frame: frame, cosmetics: cosmetics)
        }
    }

    /// Shared silhouettes for hangar shop previews.
    static func previewPath(style: String, in rect: CGRect) -> Path {
        let cx = rect.midX
        let s = min(rect.width, rect.height) / 34
        let noseY = rect.minY + 4 * s
        let tailY = rect.maxY - 3 * s
        let wing = 14 * s
        let frame = ShipDrawFrame(cx: cx, y: rect.midY, noseY: noseY, tailY: tailY, wing: wing, s: s, hullAlpha: 1)
        let bez: UIBezierPath
        switch style {
        case "fighter": bez = fighterFuselagePath(frame)
        case "interceptor": bez = interceptorFuselagePath(frame)
        case "phantom": bez = phantomHullPath(frame)
        case "inferno": bez = infernoFuselagePath(frame)
        default: bez = scoutFuselagePath(frame)
        }
        return Path(bez.cgPath)
    }

    private struct ShipDrawFrame {
        let cx: CGFloat
        let y: CGFloat
        let noseY: CGFloat
        let tailY: CGFloat
        let wing: CGFloat
        let s: CGFloat
        let hullAlpha: CGFloat
    }

    private static func shipFrame(
        center: CGPoint,
        scale: CGFloat,
        action: VaultRunEngine.PlayerAction,
        jumpLift: CGFloat,
        style: String
    ) -> ShipDrawFrame {
        var shipScale = scale
        var y = center.y
        let hullAlpha: CGFloat = style == "phantom" ? 0.78 : 1
        switch action {
        case .running: y -= jumpLift * 16 * scale
        case .jumping: y -= jumpLift * 22 * scale
        case .sliding: shipScale *= 0.42
        }
        var noseY = y - 22 * shipScale
        let tailY = y + 16 * shipScale
        var wing = 18 * shipScale
        switch style {
        case "fighter": wing *= 1.22
        case "interceptor":
            wing *= 0.75
            noseY = y - 28 * shipScale
        case "inferno": wing *= 1.12
        default: break
        }
        return ShipDrawFrame(cx: center.x, y: y, noseY: noseY, tailY: tailY, wing: wing, s: shipScale, hullAlpha: hullAlpha)
    }

    private static func hullShade(_ base: UIColor, darker: CGFloat = 0.28) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        base.getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: max(0, r - darker), green: max(0, g - darker), blue: max(0, b - darker), alpha: a)
    }

    private static func fillPath(_ ctx: CGContext, _ path: UIBezierPath, color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }

    private static func strokePath(_ ctx: CGContext, _ path: UIBezierPath, color: UIColor, width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineJoin(.round)
        ctx.addPath(path.cgPath)
        ctx.strokePath()
    }

    private static func drawCanopy(
        _ ctx: CGContext,
        frame: ShipDrawFrame,
        cosmetics: VaultRunShipCosmetics,
        rect: CGRect,
        rounded: Bool = true
    ) {
        ctx.setFillColor(cosmetics.cockpit.withAlphaComponent(0.92 * frame.hullAlpha).cgColor)
        if rounded {
            ctx.fillEllipse(in: rect)
            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.4).cgColor)
            ctx.setLineWidth(max(0.8, frame.s))
            ctx.strokeEllipse(in: rect.insetBy(dx: frame.s * 0.4, dy: frame.s * 0.4))
        } else {
            fillPath(ctx, UIBezierPath(roundedRect: rect, cornerRadius: 2 * frame.s), color: cosmetics.cockpit.withAlphaComponent(0.92 * frame.hullAlpha))
        }
        ctx.setFillColor(UIColor.white.withAlphaComponent(0.35).cgColor)
        ctx.fillEllipse(in: CGRect(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.12, width: rect.width * 0.35, height: rect.height * 0.28))
    }

    private static func drawEngineBell(
        _ ctx: CGContext,
        at point: CGPoint,
        radius: CGFloat,
        cosmetics: VaultRunShipCosmetics,
        flameH: CGFloat
    ) {
        let bell = CGRect(x: point.x - radius, y: point.y - radius * 0.4, width: radius * 2, height: radius * 1.4)
        ctx.setFillColor(hullShade(cosmetics.hull).cgColor)
        ctx.fillEllipse(in: bell)
        ctx.setFillColor(cosmetics.trail.withAlphaComponent(0.85).cgColor)
        ctx.fillEllipse(in: CGRect(x: point.x - radius * 0.65, y: point.y, width: radius * 1.3, height: flameH))
        ctx.setFillColor(VaultRunTheme.engineCore.withAlphaComponent(0.9).cgColor)
        ctx.fillEllipse(in: CGRect(x: point.x - radius * 0.35, y: point.y + flameH * 0.15, width: radius * 0.7, height: flameH * 0.45))
    }

    // MARK: Scout — recon shuttle with side pods + rear fins

    private static func scoutFuselagePath(_ f: ShipDrawFrame) -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: f.cx, y: f.noseY))
        p.addLine(to: CGPoint(x: f.cx - 4 * f.s, y: f.noseY + 7 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 7 * f.s, y: f.noseY + 16 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 6 * f.s, y: f.tailY - 10 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 10 * f.s, y: f.tailY - 2 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 10 * f.s, y: f.tailY + 3 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 3 * f.s, y: f.tailY - 2 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 3 * f.s, y: f.tailY - 2 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 10 * f.s, y: f.tailY + 3 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 10 * f.s, y: f.tailY - 2 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 6 * f.s, y: f.tailY - 10 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 7 * f.s, y: f.noseY + 16 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 4 * f.s, y: f.noseY + 7 * f.s))
        p.close()
        return p
    }

    private static func drawScoutHull(_ ctx: CGContext, frame: ShipDrawFrame, cosmetics: VaultRunShipCosmetics) {
        let hull = scoutFuselagePath(frame)
        fillPath(ctx, hull, color: cosmetics.hull.withAlphaComponent(frame.hullAlpha))
        strokePath(ctx, hull, color: hullShade(cosmetics.hull, darker: 0.35), width: max(1.1, 1.6 * frame.s))

        for side: CGFloat in [-1, 1] {
            let pod = CGRect(
                x: frame.cx + side * 9 * frame.s - 4 * frame.s,
                y: frame.noseY + 11 * frame.s,
                width: 8 * frame.s,
                height: 10 * frame.s
            )
            fillPath(ctx, UIBezierPath(roundedRect: pod, cornerRadius: 3 * frame.s), color: hullShade(cosmetics.hull, darker: 0.18))
            ctx.setStrokeColor(cosmetics.cockpit.withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(frame.s * 0.8)
            ctx.strokeEllipse(in: pod.insetBy(dx: 2 * frame.s, dy: 2 * frame.s))
        }

        let spine = UIBezierPath()
        spine.move(to: CGPoint(x: frame.cx, y: frame.noseY + 4 * frame.s))
        spine.addLine(to: CGPoint(x: frame.cx, y: frame.tailY - 6 * frame.s))
        strokePath(ctx, spine, color: hullShade(cosmetics.hull, darker: 0.4).withAlphaComponent(0.6), width: frame.s * 0.7)

        drawCanopy(ctx, frame: frame, cosmetics: cosmetics, rect: CGRect(
            x: frame.cx - 6 * frame.s, y: frame.noseY + 6 * frame.s, width: 12 * frame.s, height: 9 * frame.s
        ))
        drawEngineBell(ctx, at: CGPoint(x: frame.cx, y: frame.tailY - 1 * frame.s), radius: 5 * frame.s, cosmetics: cosmetics, flameH: 12 * frame.s)
    }

    // MARK: Fighter — twin-nacelle gunship with swept wings

    private static func fighterFuselagePath(_ f: ShipDrawFrame) -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: f.cx, y: f.noseY))
        p.addLine(to: CGPoint(x: f.cx - 3 * f.s, y: f.noseY + 8 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 4 * f.s, y: f.tailY - 6 * f.s))
        p.addLine(to: CGPoint(x: f.cx, y: f.tailY - 10 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 4 * f.s, y: f.tailY - 6 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 3 * f.s, y: f.noseY + 8 * f.s))
        p.close()
        return p
    }

    private static func fighterWingPath(_ f: ShipDrawFrame, side: CGFloat) -> UIBezierPath {
        let p = UIBezierPath()
        let rootY = f.noseY + 10 * f.s
        let tipX = f.cx + side * f.wing
        p.move(to: CGPoint(x: f.cx + side * 5 * f.s, y: rootY))
        p.addLine(to: CGPoint(x: tipX, y: f.tailY - 2 * f.s))
        p.addLine(to: CGPoint(x: tipX - side * 5 * f.s, y: f.tailY + 2 * f.s))
        p.addLine(to: CGPoint(x: f.cx + side * 3 * f.s, y: f.tailY - 4 * f.s))
        p.close()
        return p
    }

    private static func drawFighterHull(_ ctx: CGContext, frame: ShipDrawFrame, cosmetics: VaultRunShipCosmetics) {
        for side: CGFloat in [-1, 1] {
            let wing = fighterWingPath(frame, side: side)
            fillPath(ctx, wing, color: hullShade(cosmetics.hull, darker: 0.12).withAlphaComponent(frame.hullAlpha))
            strokePath(ctx, wing, color: hullShade(cosmetics.hull, darker: 0.32), width: max(1, 1.4 * frame.s))
        }
        let body = fighterFuselagePath(frame)
        fillPath(ctx, body, color: cosmetics.hull.withAlphaComponent(frame.hullAlpha))
        strokePath(ctx, body, color: hullShade(cosmetics.hull, darker: 0.35), width: max(1.1, 1.5 * frame.s))

        for side: CGFloat in [-1, 1] {
            let nacelle = CGRect(
                x: frame.cx + side * 11 * frame.s - 3.5 * frame.s,
                y: frame.tailY - 8 * frame.s,
                width: 7 * frame.s,
                height: 9 * frame.s
            )
            fillPath(ctx, UIBezierPath(roundedRect: nacelle, cornerRadius: 2 * frame.s), color: hullShade(cosmetics.hull, darker: 0.22))
        }

        drawCanopy(ctx, frame: frame, cosmetics: cosmetics, rect: CGRect(
            x: frame.cx - 4 * frame.s, y: frame.noseY + 5 * frame.s, width: 8 * frame.s, height: 7 * frame.s
        ), rounded: false)

        for side: CGFloat in [-1, 1] {
            drawEngineBell(
                ctx,
                at: CGPoint(x: frame.cx + side * 11 * frame.s, y: frame.tailY),
                radius: 4 * frame.s,
                cosmetics: cosmetics,
                flameH: 11 * frame.s
            )
        }
    }

    // MARK: Interceptor — needle spine + delta stabilizers

    private static func interceptorFuselagePath(_ f: ShipDrawFrame) -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: f.cx, y: f.noseY))
        p.addLine(to: CGPoint(x: f.cx - 2.5 * f.s, y: f.noseY + 18 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 3 * f.s, y: f.tailY - 4 * f.s))
        p.addLine(to: CGPoint(x: f.cx, y: f.tailY - 8 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 3 * f.s, y: f.tailY - 4 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 2.5 * f.s, y: f.noseY + 18 * f.s))
        p.close()
        return p
    }

    private static func drawInterceptorHull(_ ctx: CGContext, frame: ShipDrawFrame, cosmetics: VaultRunShipCosmetics) {
        for side: CGFloat in [-1, 1] {
            let fin = UIBezierPath()
            let baseY = frame.tailY - 12 * frame.s
            fin.move(to: CGPoint(x: frame.cx + side * 2 * frame.s, y: baseY))
            fin.addLine(to: CGPoint(x: frame.cx + side * frame.wing * 0.9, y: frame.tailY))
            fin.addLine(to: CGPoint(x: frame.cx + side * 5 * frame.s, y: frame.tailY - 2 * frame.s))
            fin.close()
            fillPath(ctx, fin, color: hullShade(cosmetics.hull, darker: 0.15).withAlphaComponent(frame.hullAlpha))
        }

        let spine = interceptorFuselagePath(frame)
        fillPath(ctx, spine, color: cosmetics.hull.withAlphaComponent(frame.hullAlpha))
        strokePath(ctx, spine, color: hullShade(cosmetics.hull, darker: 0.35), width: max(1, 1.4 * frame.s))

        ctx.setFillColor(cosmetics.cockpit.withAlphaComponent(0.5).cgColor)
        ctx.fillEllipse(in: CGRect(x: frame.cx - 1.5 * frame.s, y: frame.noseY + 4 * frame.s, width: 3 * frame.s, height: 14 * frame.s))

        drawCanopy(ctx, frame: frame, cosmetics: cosmetics, rect: CGRect(
            x: frame.cx - 3 * frame.s, y: frame.noseY + 8 * frame.s, width: 6 * frame.s, height: 5 * frame.s
        ))

        let exhaustY = frame.tailY - 2 * frame.s
        for offset: CGFloat in [-4, 0, 4] {
            drawEngineBell(
                ctx,
                at: CGPoint(x: frame.cx + offset * frame.s, y: exhaustY),
                radius: 2.8 * frame.s,
                cosmetics: cosmetics,
                flameH: 10 * frame.s
            )
        }
    }

    // MARK: Phantom — curved ghost wing with hollow profile

    private static func phantomHullPath(_ f: ShipDrawFrame) -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: f.cx, y: f.noseY + 2 * f.s))
        p.addQuadCurve(
            to: CGPoint(x: f.cx - f.wing * 0.95, y: f.tailY),
            controlPoint: CGPoint(x: f.cx - f.wing * 0.55, y: f.noseY + 20 * f.s)
        )
        p.addLine(to: CGPoint(x: f.cx - f.wing * 0.35, y: f.tailY - 4 * f.s))
        p.addQuadCurve(
            to: CGPoint(x: f.cx, y: f.noseY + 10 * f.s),
            controlPoint: CGPoint(x: f.cx - f.wing * 0.2, y: f.tailY - 10 * f.s)
        )
        p.addQuadCurve(
            to: CGPoint(x: f.cx + f.wing * 0.35, y: f.tailY - 4 * f.s),
            controlPoint: CGPoint(x: f.cx + f.wing * 0.2, y: f.tailY - 10 * f.s)
        )
        p.addLine(to: CGPoint(x: f.cx + f.wing * 0.95, y: f.tailY))
        p.addQuadCurve(
            to: CGPoint(x: f.cx, y: f.noseY + 2 * f.s),
            controlPoint: CGPoint(x: f.cx + f.wing * 0.55, y: f.noseY + 20 * f.s)
        )
        p.close()
        return p
    }

    private static func drawPhantomHull(_ ctx: CGContext, frame: ShipDrawFrame, cosmetics: VaultRunShipCosmetics) {
        let hull = phantomHullPath(frame)
        fillPath(ctx, hull, color: cosmetics.hull.withAlphaComponent(frame.hullAlpha * 0.55))
        strokePath(ctx, hull, color: cosmetics.cockpit.withAlphaComponent(0.75), width: max(1.4, 2 * frame.s))

        ctx.setStrokeColor(cosmetics.trail.withAlphaComponent(0.35).cgColor)
        ctx.setLineWidth(frame.s * 0.8)
        ctx.strokeEllipse(in: CGRect(
            x: frame.cx - frame.wing * 0.22,
            y: frame.noseY + 11 * frame.s,
            width: frame.wing * 0.44,
            height: (frame.tailY - frame.noseY) * 0.42
        ))

        drawCanopy(ctx, frame: frame, cosmetics: cosmetics, rect: CGRect(
            x: frame.cx - 5 * frame.s, y: frame.noseY + 7 * frame.s, width: 10 * frame.s, height: 6 * frame.s
        ))
        drawEngineBell(ctx, at: CGPoint(x: frame.cx, y: frame.tailY), radius: 4 * frame.s, cosmetics: cosmetics, flameH: 13 * frame.s)
    }

    // MARK: Inferno — NFG flagship with ram scoops + reactor ring

    private static func infernoFuselagePath(_ f: ShipDrawFrame) -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: f.cx, y: f.noseY - 2 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 5 * f.s, y: f.noseY + 10 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 7 * f.s, y: f.tailY - 8 * f.s))
        p.addLine(to: CGPoint(x: f.cx - 4 * f.s, y: f.tailY + 2 * f.s))
        p.addLine(to: CGPoint(x: f.cx, y: f.tailY - 4 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 4 * f.s, y: f.tailY + 2 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 7 * f.s, y: f.tailY - 8 * f.s))
        p.addLine(to: CGPoint(x: f.cx + 5 * f.s, y: f.noseY + 10 * f.s))
        p.close()
        return p
    }

    private static func drawInfernoHull(_ ctx: CGContext, frame: ShipDrawFrame, cosmetics: VaultRunShipCosmetics) {
        let dorsal = UIBezierPath()
        dorsal.move(to: CGPoint(x: frame.cx, y: frame.noseY + 3 * frame.s))
        dorsal.addLine(to: CGPoint(x: frame.cx, y: frame.tailY - 14 * frame.s))
        dorsal.addLine(to: CGPoint(x: frame.cx, y: frame.noseY - 4 * frame.s))
        dorsal.close()
        fillPath(ctx, dorsal, color: hullShade(cosmetics.hull, darker: 0.2).withAlphaComponent(frame.hullAlpha))

        for side: CGFloat in [-1, 1] {
            let scoop = UIBezierPath()
            scoop.move(to: CGPoint(x: frame.cx + side * 6 * frame.s, y: frame.noseY + 12 * frame.s))
            scoop.addLine(to: CGPoint(x: frame.cx + side * frame.wing * 0.85, y: frame.noseY + 18 * frame.s))
            scoop.addLine(to: CGPoint(x: frame.cx + side * frame.wing * 0.75, y: frame.tailY - 4 * frame.s))
            scoop.addLine(to: CGPoint(x: frame.cx + side * 5 * frame.s, y: frame.tailY - 8 * frame.s))
            scoop.close()
            fillPath(ctx, scoop, color: hullShade(cosmetics.hull, darker: 0.1).withAlphaComponent(frame.hullAlpha))
            strokePath(ctx, scoop, color: cosmetics.trail.withAlphaComponent(0.5), width: frame.s)
        }

        let body = infernoFuselagePath(frame)
        fillPath(ctx, body, color: cosmetics.hull.withAlphaComponent(frame.hullAlpha))
        strokePath(ctx, body, color: hullShade(cosmetics.hull, darker: 0.35), width: max(1.2, 1.7 * frame.s))

        let ringRect = CGRect(x: frame.cx - frame.wing * 0.5, y: frame.tailY - 6 * frame.s, width: frame.wing, height: 10 * frame.s)
        ctx.setStrokeColor(cosmetics.trail.withAlphaComponent(0.85).cgColor)
        ctx.setLineWidth(2 * frame.s)
        ctx.strokeEllipse(in: ringRect)
        ctx.setFillColor(cosmetics.trail.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in: ringRect.insetBy(dx: 3 * frame.s, dy: 2 * frame.s))

        drawCanopy(ctx, frame: frame, cosmetics: cosmetics, rect: CGRect(
            x: frame.cx - 5 * frame.s, y: frame.noseY + 6 * frame.s, width: 10 * frame.s, height: 8 * frame.s
        ))

        for side: CGFloat in [-1, 1] {
            drawEngineBell(
                ctx,
                at: CGPoint(x: frame.cx + side * 6 * frame.s, y: frame.tailY + 1 * frame.s),
                radius: 3.5 * frame.s,
                cosmetics: cosmetics,
                flameH: 12 * frame.s
            )
        }
        drawEngineBell(ctx, at: CGPoint(x: frame.cx, y: frame.tailY + 2 * frame.s), radius: 4 * frame.s, cosmetics: cosmetics, flameH: 14 * frame.s)
    }

    private static func drawShipFlames(
        _ ctx: CGContext,
        frame: ShipDrawFrame,
        action: VaultRunEngine.PlayerAction,
        cosmetics: VaultRunShipCosmetics
    ) {
        // Engine bells draw their own exhaust; keep a soft under-glow for boost.
        guard action == .jumping else { return }
        let glow = CGRect(x: frame.cx - 10 * frame.s, y: frame.tailY, width: 20 * frame.s, height: 16 * frame.s)
        ctx.setFillColor(cosmetics.trail.withAlphaComponent(0.22).cgColor)
        ctx.fillEllipse(in: glow)
    }

    static func drawShipAura(
        _ ctx: CGContext,
        center: CGPoint,
        tier: Int,
        trail: UIColor,
        cockpit: UIColor
    ) {
        let radius = 18 + CGFloat(tier) * 2.5
        let colors = [
            trail.withAlphaComponent(0.18 + CGFloat(tier) * 0.03).cgColor,
            UIColor.clear.cgColor,
        ] as CFArray
        guard let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0, 1]
        ) else { return }
        ctx.drawRadialGradient(
            grad,
            startCenter: center,
            startRadius: 4,
            endCenter: center,
            endRadius: radius,
            options: []
        )
        if tier >= 5 {
            ctx.setStrokeColor(cockpit.withAlphaComponent(0.35).cgColor)
            ctx.setLineWidth(1.2)
            ctx.strokeEllipse(in: CGRect(x: center.x - radius * 0.55, y: center.y - radius * 0.55, width: radius * 1.1, height: radius * 1.1))
        }
    }

    static func drawMilestonePulse(_ ctx: CGContext, center: CGPoint, progress: CGFloat, accent: UIColor) {
        let t = 1 - progress
        let radius = 20 + progress * 48
        ctx.setStrokeColor(accent.withAlphaComponent(0.55 * t).cgColor)
        ctx.setLineWidth(3 * t)
        ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ctx.setFillColor(accent.withAlphaComponent(0.12 * t).cgColor)
        ctx.fillEllipse(in: CGRect(x: center.x - radius * 0.6, y: center.y - radius * 0.6, width: radius * 1.2, height: radius * 1.2))
    }

}

// MARK: - SwiftUI chrome

struct VaultRunCanvasFrame<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var glow = false

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                VaultRunTheme.accentGold.opacity(glow ? 0.85 : 0.5),
                                VaultRunTheme.accentOrange.opacity(0.45),
                                VaultRunTheme.accentJade.opacity(glow ? 0.55 : 0.28),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
            )
            .shadow(color: VaultRunTheme.accentGold.opacity(glow ? 0.25 : 0.12), radius: glow ? 14 : 8, y: 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }
}

struct VaultRunStatChip: View {
    let label: String
    let value: String
    let accent: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.6)
            }
            .foregroundStyle(accent.opacity(0.85))
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VaultRunTheme.panelStone, Color(red: 0.08, green: 0.07, blue: 0.06)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(accent.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

struct VaultRunLiveDistanceBadge: View {
    let distance: Int
    let speedTier: Int
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(distance.formatted())m")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, VaultRunTheme.accentGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            if isActive, speedTier > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("Hot streak")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(VaultRunTheme.accentOrange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(VaultRunTheme.accentGold.opacity(0.45), lineWidth: 1)
                )
        )
    }
}

struct VaultRunMilestoneBanner: View {
    let nextDistance: Int
    let reward: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(VaultRunTheme.accentGold)
            Text("Next jackpot at \(nextDistance.formatted())m")
                .font(.system(size: 11, weight: .semibold))
            Spacer()
            Text("+\(reward.formatted()) pts")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(VaultRunTheme.accentGold)
        }
        .foregroundStyle(NFGTheme.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(VaultRunTheme.panelStone.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(VaultRunTheme.accentGold.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct VaultRunFullscreenBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.07, blue: 0.05),
                Color(red: 0.04, green: 0.09, blue: 0.06),
                Color(red: 0.02, green: 0.04, blue: 0.03),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private extension UIColor {
    static func vaultRunHex(_ hex: String) -> UIColor? {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if raw.hasPrefix("#") { raw.removeFirst() }
        guard raw.count == 6, let value = UInt32(raw, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}
