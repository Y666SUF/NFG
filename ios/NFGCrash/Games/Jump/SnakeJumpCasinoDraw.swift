import UIKit

enum SnakeJumpCasinoDraw {
    static func skyTier(heightM: Int) -> Int {
        min(7, heightM / 6000)
    }

    static func tierLabel(heightM: Int) -> String {
        switch skyTier(heightM: heightM) {
        case 0: return "Green Table"
        case 1: return "Count Matrix"
        case 2: return "Poker Grid"
        case 3: return "Royal Deck"
        case 4: return "High Limit"
        case 5: return "Vault Odds"
        default: return "Jackpot Code"
        }
    }

    static func skyGradient(heightM: Int) -> (UIColor, UIColor, UIColor) {
        switch skyTier(heightM: heightM) {
        case 0:
            return (
                UIColor(red: 0.04, green: 0.09, blue: 0.07, alpha: 1),
                UIColor(red: 0.05, green: 0.14, blue: 0.11, alpha: 1),
                UIColor(red: 0.02, green: 0.05, blue: 0.06, alpha: 1)
            )
        case 1:
            return (
                UIColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 1),
                UIColor(red: 0.06, green: 0.12, blue: 0.20, alpha: 1),
                UIColor(red: 0.02, green: 0.04, blue: 0.10, alpha: 1)
            )
        case 2:
            return (
                UIColor(red: 0.06, green: 0.05, blue: 0.14, alpha: 1),
                UIColor(red: 0.10, green: 0.07, blue: 0.22, alpha: 1),
                UIColor(red: 0.03, green: 0.02, blue: 0.10, alpha: 1)
            )
        case 3:
            return (
                UIColor(red: 0.10, green: 0.04, blue: 0.08, alpha: 1),
                UIColor(red: 0.14, green: 0.06, blue: 0.12, alpha: 1),
                UIColor(red: 0.05, green: 0.02, blue: 0.06, alpha: 1)
            )
        case 4:
            return (
                UIColor(red: 0.12, green: 0.08, blue: 0.03, alpha: 1),
                UIColor(red: 0.18, green: 0.12, blue: 0.05, alpha: 1),
                UIColor(red: 0.06, green: 0.04, blue: 0.02, alpha: 1)
            )
        case 5:
            return (
                UIColor(red: 0.03, green: 0.08, blue: 0.16, alpha: 1),
                UIColor(red: 0.05, green: 0.14, blue: 0.28, alpha: 1),
                UIColor(red: 0.02, green: 0.05, blue: 0.12, alpha: 1)
            )
        default:
            return (
                UIColor(red: 0.08, green: 0.14, blue: 0.28, alpha: 1),
                UIColor(red: 0.12, green: 0.22, blue: 0.42, alpha: 1),
                UIColor(red: 0.04, green: 0.08, blue: 0.18, alpha: 1)
            )
        }
    }

    // MARK: - Sky (matrix + grid — cached static layer, cheap animated rain)

    private static let matrixGlyphs = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "J", "Q", "K", "♠", "♥", "♦", "♣"]
    private static let matrixColumns = 9
    private static let matrixTrail = 6
    private static let skyStaticCache = SkyStaticLayerCache()
    private static var glyphImageCache: [String: CGImage] = [:]

    static func drawAnimatedSky(
        ctx: CGContext,
        width: CGFloat,
        height: CGFloat,
        heightM: Int,
        elapsed: Double,
        liteEffects: Bool = false
    ) {
        let tier = skyTier(heightM: heightM)
        skyStaticCache.draw(into: ctx, width: width, height: height, tier: tier)
        if liteEffects {
            return
        }
        drawSoftAmbientGlow(ctx: ctx, width: width, height: height, tier: tier, elapsed: elapsed)
        drawMatrixRain(ctx: ctx, width: width, height: height, heightM: heightM, tier: tier, elapsed: elapsed)
    }

    private static func drawPerspectiveGrid(ctx: CGContext, width: CGFloat, height: CGFloat, tier: Int) {
        let lineColor = tierAccentColor(tier: tier, alpha: 0.05)
        lineColor.setStroke()
        ctx.setLineWidth(0.5)

        let rows = 6
        let cols = 7
        for row in 0...rows {
            let t = CGFloat(row) / CGFloat(rows)
            let y = height * (0.12 + t * 0.78)
            ctx.move(to: CGPoint(x: width * 0.06, y: y))
            ctx.addLine(to: CGPoint(x: width * 0.94, y: y))
        }
        for col in 0...cols {
            let t = CGFloat(col) / CGFloat(cols)
            let x = width * (0.08 + t * 0.84)
            ctx.move(to: CGPoint(x: x, y: height * 0.12))
            ctx.addLine(to: CGPoint(x: x, y: height * 0.9))
        }
        ctx.strokePath()
    }

    private static func drawMatrixRain(
        ctx: CGContext,
        width: CGFloat,
        height: CGFloat,
        heightM: Int,
        tier: Int,
        elapsed: Double
    ) {
        let colWidth = width / CGFloat(matrixColumns)
        let charStep: CGFloat = 18
        let speed = 58 + CGFloat(tier) * 8

        for col in 0..<matrixColumns {
            let x = colWidth * CGFloat(col) + colWidth * 0.5
            let seed = Double(col) * 97.13 + Double(tier) * 17.7
            let headY = CGFloat(fmod(elapsed * Double(speed) + seed, Double(height) + Double(matrixTrail) * Double(charStep) + 48))

            var trailTop = headY
            var trailBottom = headY
            for t in 1..<matrixTrail {
                let y = headY - CGFloat(t) * charStep
                if y < -charStep || y > height + charStep { continue }
                trailBottom = y
            }

            if trailBottom < trailTop - 2 {
                let trailColor = tierAccentColor(tier: tier, alpha: 0.14)
                ctx.setStrokeColor(trailColor.cgColor)
                ctx.setLineWidth(1.5)
                ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: x, y: trailTop))
                ctx.addLine(to: CGPoint(x: x, y: trailBottom))
                ctx.strokePath()
            }

            if headY >= -charStep && headY <= height + charStep {
                let glyphIndex = (col + Int(headY) / 18 + heightM / 400 + tier * 3) % matrixGlyphs.count
                let glyph = matrixGlyphs[glyphIndex]
                let isSuit = glyph == "♠" || glyph == "♥" || glyph == "♦" || glyph == "♣"
                let headAlpha: CGFloat = 0.38
                let headColor = isSuit
                    ? tierSuitColor(tier: tier, glyph: glyph, alpha: headAlpha)
                    : tierAccentColor(tier: tier, alpha: headAlpha)
                drawCachedMatrixGlyph(ctx: ctx, glyph: glyph, center: CGPoint(x: x, y: headY), tier: tier, color: headColor, isHead: true)
            }
        }
    }

    private static func drawCachedMatrixGlyph(
        ctx: CGContext,
        glyph: String,
        center: CGPoint,
        tier: Int,
        color: UIColor,
        isHead: Bool
    ) {
        let cacheKey = "\(glyph)_\(tier)_\(isHead)"
        let cgImage: CGImage
        if let cached = glyphImageCache[cacheKey] {
            cgImage = cached
        } else {
            cgImage = rasterizeGlyph(glyph: glyph, color: color, isHead: isHead)
            glyphImageCache[cacheKey] = cgImage
        }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)
        ctx.draw(cgImage, in: CGRect(x: center.x - w * 0.5, y: center.y - h * 0.5, width: w, height: h))
    }

    private static func rasterizeGlyph(glyph: String, color: UIColor, isHead: Bool) -> CGImage {
        let fontSize: CGFloat = glyph.count > 1 ? 11 : (isHead ? 15 : 13)
        let weight: UIFont.Weight = isHead ? .bold : .medium
        let font = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: weight)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        let ns = glyph as NSString
        let textSize = ns.size(withAttributes: attrs)
        let pad: CGFloat = isHead ? 10 : 2
        let canvasW = textSize.width + pad * 2
        let canvasH = textSize.height + pad * 2
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasW, height: canvasH), format: format)
        let image = renderer.image { ctx in
            if isHead {
                color.withAlphaComponent(color.cgColor.alpha * 0.35).setFill()
                let glowR = max(textSize.width, textSize.height) * 0.65
                ctx.cgContext.fillEllipse(in: CGRect(
                    x: canvasW * 0.5 - glowR,
                    y: canvasH * 0.5 - glowR,
                    width: glowR * 2,
                    height: glowR * 2
                ))
            }
            ns.draw(at: CGPoint(x: pad, y: pad), withAttributes: attrs)
        }
        return image.cgImage!
    }

    private static func drawFocusVignette(ctx: CGContext, width: CGFloat, height: CGFloat) {
        let colors = [
            UIColor.black.withAlphaComponent(0.0).cgColor,
            UIColor.black.withAlphaComponent(0.20).cgColor,
        ] as CFArray
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: [0.55, 1.0]
        )!
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: width * 0.5, y: height * 0.35),
            end: CGPoint(x: width * 0.5, y: height),
            options: []
        )
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: width * 0.5, y: height * 0.2),
            end: CGPoint(x: width * 0.5, y: 0),
            options: []
        )
    }

    private static func tierSuitColor(tier: Int, glyph: String, alpha: CGFloat) -> UIColor {
        switch glyph {
        case "♥", "♦":
            return UIColor(red: 0.95, green: 0.32, blue: 0.42, alpha: alpha)
        default:
            return tierAccentColor(tier: tier, alpha: alpha)
        }
    }

    /// Bakes grid, watermark, and vignette once per size/tier — not redrawn every frame.
    private final class SkyStaticLayerCache {
        private var cachedImage: CGImage?
        private var cacheKey = ""

        func draw(into ctx: CGContext, width: CGFloat, height: CGFloat, tier: Int) {
            let key = "\(Int(width))x\(Int(height))_\(tier)"
            if key != cacheKey {
                cacheKey = key
                cachedImage = bake(width: width, height: height, tier: tier)
            }
            if let cachedImage {
                ctx.draw(cachedImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }

        private func bake(width: CGFloat, height: CGFloat, tier: Int) -> CGImage? {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            let image = renderer.image { ctx in
                let cg = ctx.cgContext
                SnakeJumpCasinoDraw.drawPerspectiveGrid(ctx: cg, width: width, height: height, tier: tier)
                SnakeJumpCasinoDraw.drawSubtleWatermark(ctx: cg, width: width, height: height, tier: tier)
                SnakeJumpCasinoDraw.drawFocusVignette(ctx: cg, width: width, height: height)
            }
            return image.cgImage
        }
    }

    private static func drawSoftAmbientGlow(
        ctx: CGContext,
        width: CGFloat,
        height: CGFloat,
        tier: Int,
        elapsed: Double
    ) {
        let base = tierAccentColor(tier: tier, alpha: 0.06)
        for i in 0..<3 {
            let phase = elapsed * 0.15 + Double(i) * 2.1
            let cx = width * (0.25 + CGFloat(i) * 0.25) + CGFloat(sin(phase) * 12)
            let cy = height * (0.25 + CGFloat(i) * 0.2) + CGFloat(cos(phase * 0.8) * 10)
            let r = width * (0.28 + CGFloat(i) * 0.04)
            base.setFill()
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
    }

    private static func drawSubtleWatermark(ctx: CGContext, width: CGFloat, height: CGFloat, tier: Int) {
        let glyph = tierWatermarkGlyph(tier: tier)
        let fontSize = min(width, height) * 0.38
        let font = UIFont.systemFont(ofSize: fontSize, weight: .ultraLight)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: tierAccentColor(tier: tier, alpha: 0.035),
        ]
        let ns = glyph as NSString
        let size = ns.size(withAttributes: attrs)
        ns.draw(at: CGPoint(x: (width - size.width) * 0.5, y: (height - size.height) * 0.45), withAttributes: attrs)
    }

    private static func tierAccentColor(tier: Int, alpha: CGFloat) -> UIColor {
        switch tier {
        case 0:
            return UIColor(red: 0.35, green: 0.92, blue: 0.62, alpha: alpha)
        case 1:
            return UIColor(red: 0.45, green: 0.78, blue: 1.0, alpha: alpha)
        case 2:
            return UIColor(red: 0.62, green: 0.48, blue: 1.0, alpha: alpha)
        case 3:
            return UIColor(red: 1.0, green: 0.42, blue: 0.55, alpha: alpha)
        case 4:
            return UIColor(red: 1.0, green: 0.78, blue: 0.28, alpha: alpha)
        case 5:
            return UIColor(red: 0.38, green: 0.82, blue: 1.0, alpha: alpha)
        default:
            return UIColor(red: 0.55, green: 0.88, blue: 1.0, alpha: alpha)
        }
    }

    private static func tierWatermarkGlyph(tier: Int) -> String {
        switch tier {
        case 0: return "♣"
        case 1: return "7"
        case 2: return "♠"
        case 3: return "♥"
        case 4: return "K"
        case 5: return "♦"
        default: return "A"
        }
    }

    // MARK: - Platforms (3D casino felt / chip / slot / bust)

    static func drawPlatform(
        ctx: CGContext,
        kind: String,
        px: CGFloat,
        py: CGFloat,
        pw: CGFloat,
        elapsed: Double,
        crumbleUsed: Bool,
        crumbleBreakAt: Double?,
        engineElapsed: Double
    ) {
        let h: CGFloat = 16
        let depth: CGFloat = 5
        let rect = CGRect(x: px - pw * 0.5, y: py - h * 0.5, width: pw, height: h)
        var alpha: CGFloat = 1
        if kind == "crumble", crumbleUsed, let breakAt = crumbleBreakAt {
            let start = breakAt - 0.22
            let progress = CGFloat(min(1, max(0, (engineElapsed - start) / 0.22)))
            alpha = 1 - progress
            if alpha <= 0.02 { return }
            ctx.saveGState()
            ctx.setAlpha(alpha)
        }

        switch kind {
        case "crumble":
            drawChipPlatform3D(ctx: ctx, rect: rect, depth: depth, elapsed: elapsed, cracking: crumbleUsed)
        case "moving":
            drawSlotPlatform3D(ctx: ctx, rect: rect, depth: depth, elapsed: elapsed)
        case "deadly":
            drawBustPlatform3D(ctx: ctx, rect: rect, depth: depth, px: px, py: py, pw: pw)
        default:
            drawFeltPlatform3D(ctx: ctx, rect: rect, depth: depth, elapsed: elapsed)
        }

        if kind == "crumble", crumbleUsed {
            ctx.restoreGState()
        }
    }

    private static func drawPlatformShadow(ctx: CGContext, rect: CGRect, depth: CGFloat) {
        let shadow = rect.offsetBy(dx: 3, dy: depth + 2).insetBy(dx: -2, dy: 0)
        UIColor.black.withAlphaComponent(0.4).setFill()
        UIBezierPath(roundedRect: shadow, cornerRadius: 6).fill()
    }

    private static func drawExtrudedTop(
        ctx: CGContext,
        rect: CGRect,
        depth: CGFloat,
        topColors: [UIColor],
        frontColor: UIColor,
        rimColor: UIColor
    ) {
        drawPlatformShadow(ctx: ctx, rect: rect, depth: depth)
        let lip = CGRect(x: rect.minX + 1, y: rect.maxY - depth, width: rect.width - 2, height: depth)
        frontColor.setFill()
        UIBezierPath(roundedRect: lip, cornerRadius: 3).fill()

        let path = UIBezierPath(roundedRect: rect, cornerRadius: 5)
        ctx.saveGState()
        path.addClip()
        let grad = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: topColors.map(\.cgColor) as CFArray,
            locations: [0, 0.45, 1]
        )!
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: rect.minX, y: rect.minY),
            end: CGPoint(x: rect.minX, y: rect.maxY),
            options: []
        )
        UIColor.white.withAlphaComponent(0.22).setFill()
        ctx.fill(CGRect(x: rect.minX + 4, y: rect.minY + 2, width: rect.width * 0.55, height: rect.height * 0.35))
        ctx.restoreGState()

        rimColor.setStroke()
        ctx.setLineWidth(1.8)
        path.stroke()
    }

    private static func drawFeltPlatform3D(ctx: CGContext, rect: CGRect, depth: CGFloat, elapsed: Double) {
        let top = [
            UIColor(red: 0.14, green: 0.58, blue: 0.34, alpha: 1),
            UIColor(red: 0.06, green: 0.38, blue: 0.22, alpha: 1),
            UIColor(red: 0.04, green: 0.28, blue: 0.16, alpha: 1),
        ]
        drawExtrudedTop(
            ctx: ctx,
            rect: rect,
            depth: depth,
            topColors: top,
            frontColor: UIColor(red: 0.05, green: 0.22, blue: 0.14, alpha: 1),
            rimColor: UIColor(red: 0.78, green: 0.62, blue: 0.22, alpha: 0.9)
        )
        UIColor(red: 0.12, green: 0.55, blue: 0.32, alpha: 0.4).setFill()
        ctx.fill(CGRect(x: rect.minX + 8, y: rect.midY - 1, width: rect.width - 16, height: 2))
        drawChipStack3D(ctx: ctx, x: rect.minX + 14, y: rect.midY - 1, color: UIColor(red: 0.9, green: 0.15, blue: 0.2, alpha: 1), elapsed: elapsed)
        drawChipStack3D(ctx: ctx, x: rect.maxX - 14, y: rect.midY - 1, color: UIColor(red: 0.15, green: 0.45, blue: 0.95, alpha: 1), elapsed: elapsed + 1.2)
    }

    private static func drawChipPlatform3D(ctx: CGContext, rect: CGRect, depth: CGFloat, elapsed: Double, cracking: Bool) {
        let top = [
            UIColor(red: 0.98, green: 0.82, blue: 0.28, alpha: 1),
            UIColor(red: 0.88, green: 0.58, blue: 0.10, alpha: 1),
            UIColor(red: 0.62, green: 0.38, blue: 0.06, alpha: 1),
        ]
        drawExtrudedTop(
            ctx: ctx,
            rect: rect,
            depth: depth,
            topColors: top,
            frontColor: UIColor(red: 0.45, green: 0.28, blue: 0.05, alpha: 1),
            rimColor: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 0.95)
        )
        let chipStep = max(16, rect.width / 5)
        for i in 0..<Int(rect.width / chipStep) {
            let cx = rect.minX + CGFloat(i) * chipStep + chipStep * 0.5
            drawMiniChip3D(ctx: ctx, x: cx, y: rect.midY - 3, r: 5.5, color: UIColor(red: 0.96, green: 0.76, blue: 0.18, alpha: 1))
        }
        if cracking {
            UIColor(red: 0.25, green: 0.12, blue: 0.04, alpha: 0.85).setStroke()
            ctx.setLineWidth(1.6)
            ctx.move(to: CGPoint(x: rect.midX - 10, y: rect.minY + 2))
            ctx.addLine(to: CGPoint(x: rect.midX + 8, y: rect.maxY - 2))
            ctx.move(to: CGPoint(x: rect.midX + 4, y: rect.minY + 1))
            ctx.addLine(to: CGPoint(x: rect.midX - 12, y: rect.maxY - 1))
            ctx.strokePath()
        }
    }

    private static func drawSlotPlatform3D(ctx: CGContext, rect: CGRect, depth: CGFloat, elapsed: Double) {
        drawPlatformShadow(ctx: ctx, rect: rect, depth: depth)
        let lip = CGRect(x: rect.minX + 1, y: rect.maxY - depth, width: rect.width - 2, height: depth)
        UIColor(red: 0.08, green: 0.05, blue: 0.18, alpha: 1).setFill()
        UIBezierPath(roundedRect: lip, cornerRadius: 3).fill()

        let path = UIBezierPath(roundedRect: rect, cornerRadius: 5)
        ctx.saveGState()
        path.addClip()
        UIColor(red: 0.12, green: 0.08, blue: 0.22, alpha: 1).setFill()
        ctx.fill(rect)
        let stripeW = max(9, rect.width / 6)
        let colors: [UIColor] = [
            UIColor(red: 0.95, green: 0.2, blue: 0.45, alpha: 0.9),
            UIColor(red: 0.2, green: 0.75, blue: 1, alpha: 0.9),
            UIColor(red: 0.95, green: 0.82, blue: 0.2, alpha: 0.9),
        ]
        let offset = CGFloat(fmod(elapsed * 32, Double(stripeW)))
        var x = rect.minX - stripeW + offset
        var idx = 0
        while x < rect.maxX {
            colors[idx % colors.count].setFill()
            ctx.fill(CGRect(x: x, y: rect.minY + 2, width: stripeW * 0.72, height: rect.height - 4))
            x += stripeW
            idx += 1
        }
        ctx.restoreGState()

        UIColor(red: 0.55, green: 0.35, blue: 1, alpha: 0.65).setStroke()
        ctx.setLineWidth(1.5)
        path.stroke()
        let glow = 0.5 + 0.5 * sin(elapsed * 5)
        UIColor(red: 1, green: 0.3, blue: 0.6, alpha: 0.15 * glow).setFill()
        ctx.fill(rect.insetBy(dx: 2, dy: 2))
    }

    private static func drawBustPlatform3D(ctx: CGContext, rect: CGRect, depth: CGFloat, px: CGFloat, py: CGFloat, pw: CGFloat) {
        drawExtrudedTop(
            ctx: ctx,
            rect: rect,
            depth: depth,
            topColors: [
                UIColor(red: 0.45, green: 0.06, blue: 0.10, alpha: 1),
                UIColor(red: 0.28, green: 0.04, blue: 0.06, alpha: 1),
            ],
            frontColor: UIColor(red: 0.18, green: 0.02, blue: 0.04, alpha: 1),
            rimColor: UIColor(red: 0.95, green: 0.2, blue: 0.25, alpha: 0.8)
        )
        let spikeW = max(8, pw / 10)
        let spikeH: CGFloat = 14
        let count = max(2, Int(floor(pw / spikeW)))
        let step = pw / CGFloat(count)
        for i in 0..<count {
            let x = px - pw * 0.5 + CGFloat(i) * step + (step - spikeW) * 0.5
            let top = py - rect.height * 0.5 - spikeH
            UIColor(red: 0.85, green: 0.08, blue: 0.12, alpha: 1).setFill()
            ctx.move(to: CGPoint(x: x, y: py - rect.height * 0.5))
            ctx.addLine(to: CGPoint(x: x + spikeW * 0.5, y: top))
            ctx.addLine(to: CGPoint(x: x + spikeW, y: py - rect.height * 0.5))
            ctx.closePath()
            ctx.fillPath()
        }
        let xSize: CGFloat = 8
        UIColor.white.withAlphaComponent(0.7).setStroke()
        ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: px - xSize, y: py - 1))
        ctx.addLine(to: CGPoint(x: px + xSize, y: py + 5))
        ctx.move(to: CGPoint(x: px + xSize, y: py - 1))
        ctx.addLine(to: CGPoint(x: px - xSize, y: py + 5))
        ctx.strokePath()
    }

    private static func drawChipStack3D(ctx: CGContext, x: CGFloat, y: CGFloat, color: UIColor, elapsed: Double) {
        let wobble = CGFloat(sin(elapsed * 3.5) * 0.8)
        for i in 0..<4 {
            let r: CGFloat = 6
            let oy = CGFloat(i) * -2.5 + wobble
            UIColor.black.withAlphaComponent(0.2).setFill()
            ctx.fillEllipse(in: CGRect(x: x - r + 1, y: y - r + oy + 2, width: r * 2, height: r * 2))
            color.withAlphaComponent(0.95 - CGFloat(i) * 0.12).setFill()
            ctx.fillEllipse(in: CGRect(x: x - r, y: y - r + oy, width: r * 2, height: r * 2))
            UIColor.white.withAlphaComponent(0.3).setStroke()
            ctx.setLineWidth(0.8)
            ctx.strokeEllipse(in: CGRect(x: x - r, y: y - r + oy, width: r * 2, height: r * 2))
        }
    }

    private static func drawMiniChip3D(ctx: CGContext, x: CGFloat, y: CGFloat, r: CGFloat, color: UIColor) {
        UIColor.black.withAlphaComponent(0.25).setFill()
        ctx.fillEllipse(in: CGRect(x: x - r + 1, y: y - r + 2, width: r * 2, height: r * 2))
        color.setFill()
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
        UIColor.white.withAlphaComponent(0.35).setStroke()
        ctx.setLineWidth(0.7)
        ctx.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    static func drawPowerUp(ctx: CGContext, x: CGFloat, y: CGFloat, elapsed: Double, seed: Double) {
        let pulse = 0.86 + 0.14 * sin(elapsed * 5.2 + seed)
        let r = 13 * pulse
        SnakeJumpTheme.climbGold.withAlphaComponent(0.35 * pulse).setFill()
        ctx.fillEllipse(in: CGRect(x: x - r * 2.4, y: y - r * 2.4, width: r * 4.8, height: r * 4.8))

        let isSeven = seed.truncatingRemainder(dividingBy: 1) > 0.45
        if isSeven {
            let card = CGRect(x: x - r * 1.0, y: y - r * 0.7, width: r * 2, height: r * 1.4)
            UIColor.black.withAlphaComponent(0.3).setFill()
            UIBezierPath(roundedRect: card.offsetBy(dx: 2, dy: 3), cornerRadius: 4).fill()
            UIColor(red: 0.95, green: 0.15, blue: 0.25, alpha: 0.95).setFill()
            UIBezierPath(roundedRect: card, cornerRadius: 4).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: r * 1.2, weight: .black),
                .foregroundColor: UIColor.white,
            ]
            let label = "7" as NSString
            let size = label.size(withAttributes: attrs)
            label.draw(at: CGPoint(x: x - size.width * 0.5, y: y - size.height * 0.5), withAttributes: attrs)
        } else {
            UIColor.black.withAlphaComponent(0.25).setFill()
            let d = r * 0.58
            ctx.fillEllipse(in: CGRect(x: x - d + 2, y: y - d + 2, width: d * 2, height: d * 2))
            UIColor.white.setFill()
            ctx.fillEllipse(in: CGRect(x: x - d, y: y - d, width: d * 2, height: d * 2))
            UIColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1).setFill()
            let pip = d * 0.22
            ctx.fillEllipse(in: CGRect(x: x - pip, y: y - pip * 2.2, width: pip * 2, height: pip * 2))
            ctx.fillEllipse(in: CGRect(x: x - pip, y: y + pip * 0.2, width: pip * 2, height: pip * 2))
            ctx.fillEllipse(in: CGRect(x: x - pip, y: y - pip, width: pip * 2, height: pip * 2))
        }
        SnakeJumpTheme.climbGold.withAlphaComponent(0.85).setStroke()
        ctx.setLineWidth(1.6)
        ctx.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }
}
