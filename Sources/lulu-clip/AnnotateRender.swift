import AppKit
import LuluClipCore

enum Palette {
    static var colors: [NSColor] { [
        AnnotateTheme.inkRed, AnnotateTheme.hex(0xF5A524), AnnotateTheme.hex(0x30A46C),
        AnnotateTheme.hex(0x3B82F6), .white, AnnotateTheme.charcoal,
    ] }
    static let names = ["红", "琥珀", "绿", "蓝", "白", "炭黑"]
    static let widths: [CGFloat] = [2, 4, 7]
    static let fontSizes: [CGFloat] = [14, 20, 30]

    static func color(_ i: Int) -> NSColor { colors.indices.contains(i) ? colors[i] : colors[0] }

    static func isDark(_ c: NSColor) -> Bool {
        guard let rgb = c.usingColorSpace(.sRGB) else { return true }
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent < 0.3
    }

    static func isLight(_ c: NSColor) -> Bool {
        guard let rgb = c.usingColorSpace(.sRGB) else { return false }
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent > 0.6
    }
}

/// Draws markups into any CGContext (overlay view or the final bitmap), same styling both places.
enum MarkupRenderer {
    static func textAttributes(color: Int, fontSize: CGFloat, shadowScale: CGFloat = 1) -> [NSAttributedString.Key: Any] {
        let c = Palette.color(color)
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 2.5 * shadowScale
        shadow.shadowOffset = .zero
        shadow.shadowColor = Palette.isDark(c) ? NSColor.white.withAlphaComponent(0.9) : NSColor.black.withAlphaComponent(0.55)
        return [
            .font: AnnotateTheme.rounded(fontSize),
            .foregroundColor: c,
            .shadow: shadow,
        ]
    }

    static func textSize(_ text: String, fontSize: CGFloat) -> CGSize {
        let s = NSAttributedString(string: text, attributes: textAttributes(color: 0, fontSize: fontSize)).size()
        return CGSize(width: ceil(s.width), height: ceil(s.height))
    }

    /// `shadowScale`: CG shadows ignore the CTM, so the bitmap pass passes its pixel scale.
    static func draw(_ m: Markup, in ctx: CGContext, shadowScale: CGFloat = 1) {
        ctx.saveGState()
        defer { ctx.restoreGState() }
        let color = Palette.color(m.color).cgColor
        ctx.setStrokeColor(color)
        ctx.setFillColor(color)
        ctx.setLineWidth(m.width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        switch m.kind {
        case .line:
            ctx.move(to: m.a); ctx.addLine(to: m.b); ctx.strokePath()
        case .rect:
            ctx.setLineJoin(.miter)
            ctx.stroke(m.bounds)
        case .arrow:
            let dx = m.b.x - m.a.x, dy = m.b.y - m.a.y
            let len = hypot(dx, dy)
            guard len > 0.5 else { return }
            let ux = dx / len, uy = dy / len
            let head = min(max(10, m.width * 3.6), len)
            let half = head * 0.45
            let base = CGPoint(x: m.b.x - ux * head, y: m.b.y - uy * head)
            ctx.move(to: m.a)
            ctx.addLine(to: CGPoint(x: base.x + ux * 1, y: base.y + uy * 1))
            ctx.strokePath()
            ctx.move(to: m.b)
            ctx.addLine(to: CGPoint(x: base.x - uy * half, y: base.y + ux * half))
            ctx.addLine(to: CGPoint(x: base.x + uy * half, y: base.y - ux * half))
            ctx.closePath()
            ctx.fillPath()
        case .text:
            let prev = NSGraphicsContext.current
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSAttributedString(string: m.text, attributes: textAttributes(color: m.color, fontSize: m.fontSize, shadowScale: shadowScale))
                .draw(at: m.bounds.origin)
            NSGraphicsContext.current = prev
        }
    }
}
