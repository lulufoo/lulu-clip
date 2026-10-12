import AppKit

/// UI tokens: teal on neutral surfaces, light + dark, following system appearance.
enum AnnotateTheme {
    /// Preview/debug override; nil = follow NSApp appearance.
    static var forcedDark: Bool?

    static var isDark: Bool {
        if let f = forcedDark { return f }
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                blue: CGFloat(v & 0xFF) / 255, alpha: a)
    }

    /// Preview override for theme comparison (`toolbar-preview --primary`); nil = teal.
    static var previewPrimary: NSColor?

    // Light teal. `accent` = strokes/rings; `primary` = fills, with dark #042F2E ink on them.
    static var accent: NSColor { previewPrimary ?? (isDark ? hex(0x5EEAD4) : hex(0x14B8A6)) }
    static var primary: NSColor { previewPrimary ?? (isDark ? hex(0x5EEAD4) : hex(0x2DD4BF)) }
    static var primaryTop: NSColor {
        if let p = previewPrimary { return p.blended(withFraction: 0.1, of: .white) ?? p }
        return isDark ? hex(0x99F6E4) : hex(0x5EEAD4)
    }
    static var primaryBottom: NSColor {
        if let p = previewPrimary { return p.blended(withFraction: 0.08, of: .black) ?? p }
        return isDark ? hex(0x5EEAD4) : hex(0x2DD4BF)
    }
    static var primaryPressed: NSColor {
        if let p = previewPrimary { return p.blended(withFraction: 0.2, of: .black) ?? p }
        return isDark ? hex(0x2DD4BF) : hex(0x14B8A6)
    }
    static var primarySoft: NSColor { accent.withAlphaComponent(isDark ? 0.18 : 0.12) }
    /// Ink on primary fills: dark on bright fills (dark-mode teal, amber), white otherwise.
    static var onPrimary: NSColor {
        guard let c = primary.usingColorSpace(.sRGB) else { return .white }
        let l = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return l > 0.55 ? hex(0x042F2E) : .white
    }

    // Neutrals
    static var surface: NSColor { isDark ? hex(0x1C1C1F) : hex(0xFFFFFF) }
    static var surfaceRaised: NSColor { isDark ? hex(0x27272A) : hex(0xF7F7F8) }
    static var border: NSColor { isDark ? hex(0x2E2E33) : hex(0xE4E4E7) }
    static var textPrimary: NSColor { isDark ? hex(0xF4F4F5) : hex(0x18181B) }
    static var textSecondary: NSColor { isDark ? hex(0xD4D4D8) : hex(0x52525B) }
    static var hover: NSColor { isDark ? NSColor.white.withAlphaComponent(0.07) : textSecondary.withAlphaComponent(0.08) }
    static let charcoal = hex(0x27272A)
    static let inkRed = hex(0xE5484D)
    static var shadow: NSColor { NSColor.black.withAlphaComponent(isDark ? 0.45 : 0.18) }

    // Metrics
    static let barHeight: CGFloat = 40
    static let barRadius: CGFloat = 12
    static let barPadding: CGFloat = 6
    static let target: CGFloat = 30
    static let targetRadius: CGFloat = 8
    static let gap: CGFloat = 2
    static let iconSize: CGFloat = 17

    static func rounded(_ size: CGFloat, _ weight: NSFont.Weight = .semibold, mono: Bool = false) -> NSFont {
        let base = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        guard let d = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: d, size: size) ?? base
    }

    /// Layered soft shadow (0 8 24 + 0 1 2) drawn behind a rounded shape.
    static func drawShadow(_ path: NSBezierPath) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        for (y, blur, a) in [(CGFloat(-8), CGFloat(24), isDark ? 0.45 : 0.18), (-1, 2, isDark ? 0.4 : 0.12)] {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: y), blur: blur, color: NSColor.black.withAlphaComponent(a).cgColor)
            surface.setFill(); path.fill()
            ctx.restoreGState()
        }
    }

    /// Small pill label (selection W×H in primary, measurements in charcoal).
    static func drawPill(_ text: String, at p: CGPoint, in bounds: CGRect, accent: Bool) {
        let str = NSAttributedString(string: text, attributes: [
            .font: rounded(11, .semibold, mono: true), .foregroundColor: accent ? onPrimary : NSColor.white,
        ])
        let s = str.size()
        var r = CGRect(x: p.x, y: p.y, width: ceil(s.width) + 14, height: 20)
        r.origin.x = min(max(r.minX, bounds.minX + 2), bounds.maxX - r.width - 2)
        r.origin.y = min(max(r.minY, bounds.minY + 2), bounds.maxY - r.height - 2)
        let path = NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10)
        NSGraphicsContext.current?.cgContext.saveGState()
        NSGraphicsContext.current?.cgContext.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        (accent ? primary : charcoal.withAlphaComponent(0.92)).setFill()
        path.fill()
        NSGraphicsContext.current?.cgContext.restoreGState()
        str.draw(at: CGPoint(x: r.minX + 7, y: r.midY - s.height / 2))
    }
}
