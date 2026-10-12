import AppKit
import LuluClipCore

private typealias T = AnnotateTheme

/// Opaque bar: 12pt radius, 1px border, layered soft shadow. Swallows clicks.
final class SolidBar: NSView {
    enum Item {
        case mark
        case button(BarButton)
        case divider
        case segment([BarButton])
    }
    private var dividerXs: [CGFloat] = []
    private var segmentRects: [CGRect] = []
    private var markRect: CGRect?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseDragged(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func mouseMoved(with event: NSEvent) { NSCursor.arrow.set() }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .arrow) }

    func setItems(_ items: [Item]) {
        subviews.forEach { $0.removeFromSuperview() }
        dividerXs = []
        segmentRects = []
        markRect = nil
        let y = (T.barHeight - T.target) / 2
        var x = T.barPadding
        var first = true
        func place(_ b: BarButton) {
            b.frame = CGRect(x: x, y: y, width: b.width, height: T.target)
            addSubview(b)
            x += b.width
        }
        for item in items {
            switch item {
            case .mark:
                if !first { x += T.gap }
                markRect = CGRect(x: x + 3, y: (T.barHeight - 24) / 2, width: 24, height: 24)
                x += 30
            case let .button(b):
                if !first { x += T.gap }
                place(b)
            case .divider:
                x += 7
                dividerXs.append(x)
                x += 1 + 7
                first = true
                continue
            case let .segment(buttons):
                if !first { x += T.gap }
                let start = x
                x += 2
                for (i, b) in buttons.enumerated() {
                    if i > 0 { x += 2 }
                    b.inSegment = true
                    b.frame = CGRect(x: x, y: y + 2, width: b.width, height: T.target - 4)
                    addSubview(b)
                    x += b.width
                }
                x += 2
                segmentRects.append(CGRect(x: start, y: y, width: x - start, height: T.target))
            }
            first = false
        }
        x += T.barPadding
        setFrameSize(CGSize(width: x, height: T.barHeight))
        updateShadow()
        needsDisplay = true
    }

    private func updateShadow() {
        guard let layer else { return }
        layer.shadowPath = CGPath(roundedRect: bounds, cornerWidth: T.barRadius, cornerHeight: T.barRadius, transform: nil)
        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = T.isDark ? 0.45 : 0.18
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: -8)
    }

    var outline: NSBezierPath {
        NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: T.barRadius, yRadius: T.barRadius)
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = outline
        T.surface.setFill(); path.fill()
        // Subtle top highlight for depth.
        NSGradient(starting: NSColor.white.withAlphaComponent(T.isDark ? 0.04 : 0.6), ending: NSColor.white.withAlphaComponent(0))?
            .draw(in: NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: T.barRadius - 1, yRadius: T.barRadius - 1), angle: -90)
        T.border.setStroke(); path.lineWidth = 1; path.stroke()
        T.border.setFill()
        for x in dividerXs {
            NSBezierPath(roundedRect: CGRect(x: x, y: (bounds.height - 16) / 2, width: 1, height: 16), xRadius: 0.5, yRadius: 0.5).fill()
        }
        for r in segmentRects {
            T.surfaceRaised.setFill()
            NSBezierPath(roundedRect: r, xRadius: T.targetRadius + 1, yRadius: T.targetRadius + 1).fill()
        }
        if let m = markRect {
            let p = NSBezierPath(roundedRect: m, xRadius: 7, yRadius: 7)
            NSGradient(starting: T.primaryTop, ending: T.primaryBottom)?.draw(in: p, angle: -90)
            let l = NSAttributedString(string: "L", attributes: [.font: T.rounded(15, .heavy), .foregroundColor: T.onPrimary])
            let s = l.size()
            l.draw(at: CGPoint(x: m.midX - s.width / 2 + 0.5, y: m.midY - s.height / 2))
        }
    }
}

/// 30×30 target (or wider pill). Never takes key focus, so shortcuts keep working.
final class BarButton: NSView {
    enum Content {
        case symbol(String)
        case swatch(NSColor)
        case dot(CGFloat)
        case label(String)
        case primary(String, String) // symbol, title
    }

    let content: Content
    var inSegment = false
    var isActive = false {
        didSet {
            guard oldValue != isActive else { return }
            if window == nil { activeT = isActive ? 1 : 0; needsDisplay = true } else { animate(\.activeT, to: isActive ? 1 : 0) }
        }
    }
    var isEnabled = true { didSet { needsDisplay = true } }
    var onClick: () -> Void
    private var hovering = false { didSet { animate(\.hoverT, to: hovering ? 1 : 0) } }
    private var pressed = false { didSet { needsDisplay = true } }
    private var hoverT: CGFloat = 0
    private var activeT: CGFloat = 0
    private var timers: [PartialKeyPath<BarButton>: Timer] = [:]

    var width: CGFloat {
        if case let .primary(_, title) = content {
            let w = NSAttributedString(string: title, attributes: [.font: T.rounded(13)]).size().width
            return ceil(w) + 17 + 6 + 24
        }
        if case .label = content { return 32 }
        return T.target
    }

    init(_ content: Content, tip: String, active: Bool = false, onClick: @escaping () -> Void) {
        self.content = content
        self.onClick = onClick
        self.isActive = active
        self.activeT = active ? 1 : 0
        super.init(frame: NSRect(x: 0, y: 0, width: T.target, height: T.target))
        toolTip = tip
    }
    required init?(coder: NSCoder) { fatalError() }

    /// ~120ms ease-out toward `target`.
    private func animate(_ key: ReferenceWritableKeyPath<BarButton, CGFloat>, to target: CGFloat) {
        timers[key]?.invalidate()
        let start = self[keyPath: key]
        let began = CACurrentMediaTime()
        let t = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let p = min(1, (CACurrentMediaTime() - began) / 0.12)
            let e = 1 - pow(1 - p, 3)
            self[keyPath: key] = start + (target - start) * e
            self.needsDisplay = true
            if p >= 1 { timer.invalidate() }
        }
        RunLoop.main.add(t, forMode: .common)
        timers[key] = t
    }

    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .arrow) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
    }
    override func mouseEntered(with event: NSEvent) { if isEnabled { hovering = true } }
    override func mouseExited(with event: NSEvent) { hovering = false; pressed = false }
    override func cursorUpdate(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseMoved(with event: NSEvent) { NSCursor.arrow.set() }
    override func mouseDown(with event: NSEvent) { if isEnabled { pressed = true } }
    override func mouseDragged(with event: NSEvent) {
        pressed = isEnabled && bounds.contains(convert(event.locationInWindow, from: nil))
    }
    override func mouseUp(with event: NSEvent) {
        let fire = pressed
        pressed = false
        if fire { onClick() }
    }

    override func draw(_ dirtyRect: NSRect) {
        let alpha: CGFloat = isEnabled ? 1 : 0.3
        let radius = inSegment ? T.targetRadius - 2 : T.targetRadius
        let pill = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        if case let .primary(sym, title) = content {
            let p = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
            if pressed {
                T.primaryPressed.setFill(); p.fill()
            } else {
                NSGradient(starting: T.primaryTop.blended(withFraction: hoverT * 0.12, of: .white) ?? T.primaryTop,
                           ending: T.primaryBottom)?.draw(in: p, angle: -90)
            }
            NSColor.white.withAlphaComponent(0.22).setStroke()
            let hl = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: bounds.height / 2 - 0.5, yRadius: bounds.height / 2 - 0.5)
            hl.lineWidth = 1; hl.stroke()
            let img = symbol(sym, size: 13, weight: .bold, color: T.onPrimary)
            let str = NSAttributedString(string: title, attributes: [.font: T.rounded(13), .foregroundColor: T.onPrimary])
            let s = str.size()
            let total = (img?.size.width ?? 0) + 5 + s.width
            var x = (bounds.width - total) / 2
            if let img {
                img.draw(in: CGRect(x: x, y: (bounds.height - img.size.height) / 2, width: img.size.width, height: img.size.height))
                x += img.size.width + 5
            }
            str.draw(at: CGPoint(x: x, y: (bounds.height - s.height) / 2))
            return
        }

        if case let .swatch(color) = content {
            if hoverT > 0 { T.hover.withAlphaComponent(T.hover.alphaComponent * hoverT).setFill(); pill.fill() }
            let d: CGFloat = 18
            let r = CGRect(x: (bounds.width - d) / 2, y: (bounds.height - d) / 2, width: d, height: d)
            if activeT > 0 {
                let outer = NSBezierPath(ovalIn: r.insetBy(dx: -4 * activeT, dy: -4 * activeT))
                T.accent.withAlphaComponent(activeT).setFill(); outer.fill()
                T.surface.setFill(); NSBezierPath(ovalIn: r.insetBy(dx: -2 * activeT, dy: -2 * activeT)).fill()
            }
            color.setFill(); NSBezierPath(ovalIn: r).fill()
            (T.isDark ? NSColor.white.withAlphaComponent(0.28) : NSColor.black.withAlphaComponent(0.12)).setStroke()
            let edge = NSBezierPath(ovalIn: r.insetBy(dx: 0.5, dy: 0.5)); edge.lineWidth = 1; edge.stroke()
            return
        }

        // Ghost background: hover tint, then active primary fill blended in.
        if hoverT > 0, activeT < 1 {
            T.hover.withAlphaComponent(T.hover.alphaComponent * hoverT * (1 - activeT)).setFill(); pill.fill()
        }
        if pressed && !isActive { T.hover.setFill(); pill.fill(); T.hover.setFill(); pill.fill() }
        if activeT > 0 {
            NSGraphicsContext.saveGraphicsState()
            (pressed ? T.primaryPressed : T.primary).withAlphaComponent(activeT).setFill()
            pill.fill()
            // Inner highlight.
            NSColor.white.withAlphaComponent(0.25 * activeT).setStroke()
            let hl = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: radius - 0.5, yRadius: radius - 0.5)
            hl.lineWidth = 1; hl.stroke()
            NSGraphicsContext.restoreGraphicsState()
        }
        let base = (hoverT > 0.5 ? T.textPrimary : T.textSecondary)
        let ink = (base.blended(withFraction: activeT, of: T.onPrimary) ?? base).withAlphaComponent(alpha)
        switch content {
        case let .symbol(name):
            guard let img = symbol(name, size: T.iconSize, weight: .medium, color: ink) else { return }
            img.draw(in: CGRect(x: (bounds.width - img.size.width) / 2, y: (bounds.height - img.size.height) / 2,
                                width: img.size.width, height: img.size.height))
        case let .dot(d):
            ink.setFill()
            NSBezierPath(ovalIn: CGRect(x: (bounds.width - d) / 2, y: (bounds.height - d) / 2, width: d, height: d)).fill()
        case let .label(text):
            let str = NSAttributedString(string: text, attributes: [.font: T.rounded(13, .bold), .foregroundColor: ink])
            let s = str.size()
            str.draw(at: CGPoint(x: (bounds.width - s.width) / 2, y: (bounds.height - s.height) / 2))
        default:
            break
        }
    }

    private func symbol(_ name: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSImage? {
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
            .applying(.init(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: toolTip)?.withSymbolConfiguration(cfg)
    }
}

/// Main tool bar + attached style bar for the overlay view.
@MainActor
final class AnnotateToolbar {
    unowned let host: OverlayView
    let main = SolidBar()
    let style = SolidBar()
    private var toolButtons: [(AnnotateSession.Tool, BarButton)] = []
    private var undoButton: BarButton!
    private var redoButton: BarButton!
    private var styleKey = ""

    init(host: OverlayView) {
        self.host = host
        func tool(_ t: AnnotateSession.Tool, _ sym: String, _ tip: String) -> SolidBar.Item {
            let b = BarButton(.symbol(sym), tip: tip) { [unowned host] in host.pick(t) }
            toolButtons.append((t, b))
            return .button(b)
        }
        undoButton = BarButton(.symbol("arrow.uturn.backward"), tip: "撤销 ⌘Z") { [unowned host] in host.undo() }
        redoButton = BarButton(.symbol("arrow.uturn.forward"), tip: "重做 ⌘⇧Z") { [unowned host] in host.redo() }
        main.setItems([
            .mark,
            .divider,
            tool(.select, "hand.raised", "选择 V"),
            tool(.line, "line.diagonal", "直线 L"),
            tool(.arrow, "arrow.up.right", "箭头 A"),
            tool(.rect, "rectangle", "矩形 R"),
            tool(.text, "textformat", "文字 T"),
            .divider,
            .button(undoButton),
            .button(redoButton),
            .divider,
            .button(BarButton(.symbol("xmark"), tip: "取消 Esc") { [unowned host] in host.session.cancel() }),
            .button(BarButton(.primary("checkmark", "完成"), tip: "完成 ↩") { [unowned host] in host.finish() }),
        ])
        host.addSubview(main)
        style.isHidden = true
        host.addSubview(style)
    }

    func refresh() {
        let s = host.session
        for (tool, b) in toolButtons { b.isActive = tool == s.tool }
        undoButton.isEnabled = s.history.canUndo
        redoButton.isEnabled = s.history.canRedo
        rebuildStyle()
        layout()
    }

    private func rebuildStyle() {
        let s = host.session
        let shape = s.selected.flatMap { s.shapes.indices.contains($0) ? s.shapes[$0] : nil }
        let showText = shape?.kind == .text || (shape == nil && s.tool == .text) || host.isEditingText
        let visible = shape != nil || s.tool != .select || host.isEditingText
        style.isHidden = !visible
        guard visible else { styleKey = ""; return }
        let color = host.editingTextColor ?? shape?.color ?? s.style.color
        let width = shape?.width ?? Palette.widths[s.style.widthIndex]
        let font = host.editingTextSize ?? shape?.fontSize ?? Palette.fontSizes[s.style.fontIndex]
        let key = "\(showText)-\(color)-\(width)-\(font)-\(T.isDark)"
        guard key != styleKey else { return }
        styleKey = key
        var items: [SolidBar.Item] = []
        for (i, c) in Palette.colors.enumerated() {
            items.append(.button(BarButton(.swatch(c), tip: Palette.names[i], active: i == color) { [unowned host] in host.setColor(i) }))
        }
        items.append(.divider)
        if showText {
            items.append(.segment(["S", "M", "L"].enumerated().map { i, label in
                BarButton(.label(label), tip: "字号 \(label)  [ ]", active: Palette.fontSizes[i] == font) { [unowned host] in host.setFont(i) }
            }))
        } else {
            items.append(.segment(Palette.widths.enumerated().map { i, w in
                BarButton(.dot([4, 7, 11][i]), tip: "线宽 \(Int(w))  [ ]", active: w == width) { [unowned host] in host.setWidth(i) }
            }))
        }
        style.setItems(items)
    }

    /// Usable area in view coords: the screen's visibleFrame inset by 8pt.
    private var usable: CGRect {
        guard let screen = host.window?.screen else { return host.bounds.insetBy(dx: 8, dy: 8) }
        let v = screen.visibleFrame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
        return v.intersection(host.bounds).insetBy(dx: 8, dy: 8)
    }

    /// Main bar: right-aligned to the selection, 8pt outside (below → above → inside bottom).
    /// Style bar sits on the far side from the selection, right-aligned with the main bar.
    func layout() {
        guard let sel = host.session.selection else { return }
        let u = usable
        let m = main.frame.size
        let sh = style.isHidden ? 0 : T.barHeight + 6
        enum Place { case below, above, inside }
        let place: Place
        var y: CGFloat
        if sel.minY - 8 - m.height - sh >= u.minY {
            place = .below; y = sel.minY - 8 - m.height
        } else if sel.maxY + 8 + m.height + sh <= u.maxY {
            place = .above; y = sel.maxY + 8
        } else if sel.minY - 8 - m.height >= u.minY {
            place = .below; y = sel.minY - 8 - m.height
        } else if sel.maxY + 8 + m.height <= u.maxY {
            place = .above; y = sel.maxY + 8
        } else {
            place = .inside; y = max(sel.minY, u.minY) + 8
        }
        let right = min(sel.maxX, u.maxX)
        let x = min(max(right - m.width, u.minX), u.maxX - m.width)
        main.setFrameOrigin(CGPoint(x: x, y: y))
        guard !style.isHidden else { return }
        let s = style.frame.size
        var sy = place == .below ? y - 6 - s.height : y + m.height + 6
        if sy < u.minY { sy = y + m.height + 6 }
        if sy + s.height > u.maxY { sy = y - 6 - s.height }
        let sx = min(max(x + m.width - s.width, u.minX), u.maxX - s.width)
        style.setFrameOrigin(CGPoint(x: sx, y: sy))
    }

    // MARK: debug preview

    /// Composed scene: sample app background, dimmed outside, frozen selection with marks, bars.
    static func renderPreview(to url: URL, dark: Bool) throws {
        _ = NSApplication.shared
        AnnotateTheme.forcedDark = dark
        defer { AnnotateTheme.forcedDark = nil }
        let size = CGSize(width: 820, height: 480)
        let scale: CGFloat = 2
        let bg = sampleBackground(size: size, scale: scale, dark: dark)

        let session = AnnotateSession(url: url.deletingLastPathComponent().appendingPathComponent("preview.png"), log: { _ in })
        let view = OverlayView(frame: NSRect(origin: .zero, size: size), session: session)
        let sel = CGRect(x: 120, y: 190, width: 560, height: 220)
        session.selection = sel
        session.activeView = view
        session.editing = true
        session.frozen = bg.cropping(to: CGRect(x: sel.minX * scale, y: (size.height - sel.maxY) * scale,
                                                width: sel.width * scale, height: sel.height * scale))
        session.shapes = [
            Markup(kind: .rect, a: CGPoint(x: 150, y: 300), b: CGPoint(x: 400, y: 380), color: 0, width: 4),
            Markup(kind: .arrow, a: CGPoint(x: 560, y: 230), b: CGPoint(x: 430, y: 310), color: 0, width: 4),
            Markup(kind: .line, a: CGPoint(x: 150, y: 280), b: CGPoint(x: 650, y: 280), color: 3, width: 2),
        ]
        let text = "这里没对齐"
        let ts = MarkupRenderer.textSize(text, fontSize: 20)
        session.shapes.append(Markup(kind: .text, a: CGPoint(x: 470, y: 222), b: CGPoint(x: 470 + ts.width, y: 222 + ts.height),
                                     color: 0, fontSize: 20, text: text))
        session.selected = 0
        session.tool = .rect
        let bar = AnnotateToolbar(host: view)
        bar.refresh()

        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let overlay = rep.copy() as? NSBitmapImageRep else { return }
        rep.size = size
        overlay.size = size
        bar.main.isHidden = true
        let styleHidden = bar.style.isHidden
        bar.style.isHidden = true
        view.cacheDisplay(in: view.bounds, to: overlay)
        bar.main.isHidden = false
        bar.style.isHidden = styleHidden

        NSGraphicsContext.saveGraphicsState()
        let g = NSGraphicsContext(bitmapImageRep: rep)!
        NSGraphicsContext.current = g
        g.cgContext.draw(bg, in: CGRect(origin: .zero, size: size))
        overlay.draw(in: CGRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        for b in [bar.main, bar.style] where !b.isHidden {
            let ctx = g.cgContext
            ctx.saveGState()
            ctx.translateBy(x: b.frame.minX, y: b.frame.minY)
            AnnotateTheme.drawShadow(b.outline)
            b.displayIgnoringOpacity(b.bounds, in: g)
            ctx.restoreGState()
        }
        NSGraphicsContext.restoreGraphicsState()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try rep.representation(using: .png, properties: [:])?.write(to: url)
    }

    /// Light-mode previews for candidate primaries; plus a stacked comparison.
    static func renderThemeCompare(dir: URL, themes: [(String, NSColor)]) throws -> [URL] {
        defer { AnnotateTheme.previewPrimary = nil }
        var outs: [URL] = []
        for (name, color) in themes {
            AnnotateTheme.previewPrimary = color
            let u = dir.appendingPathComponent("theme-\(name).png")
            try renderPreview(to: u, dark: false)
            outs.append(u)
        }
        let imgs = outs.compactMap { NSImage(contentsOf: $0) }
        guard let first = imgs.first else { return outs }
        let labelH: CGFloat = 40
        let w = first.size.width, h = first.size.height
        let total = CGSize(width: w, height: (h + labelH) * CGFloat(imgs.count))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(total.width * 2), pixelsHigh: Int(total.height * 2),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return outs }
        rep.size = total
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill(); CGRect(origin: .zero, size: total).fill()
        for (i, img) in imgs.enumerated() {
            let top = total.height - CGFloat(i) * (h + labelH)
            let (name, color) = themes[i]
            color.setFill()
            NSBezierPath(roundedRect: CGRect(x: 20, y: top - 28, width: 16, height: 16), xRadius: 4, yRadius: 4).fill()
            let hex = color.usingColorSpace(.sRGB).map { String(format: "#%02X%02X%02X", Int($0.redComponent * 255 + 0.5), Int($0.greenComponent * 255 + 0.5), Int($0.blueComponent * 255 + 0.5)) } ?? ""
            NSAttributedString(string: "\(i + 1). \(name)  \(hex)", attributes: [.font: AnnotateTheme.rounded(16, .bold), .foregroundColor: NSColor(white: 0.1, alpha: 1)])
                .draw(at: CGPoint(x: 44, y: top - 31))
            img.draw(in: CGRect(x: 0, y: top - labelH - h, width: w, height: h))
        }
        NSGraphicsContext.restoreGraphicsState()
        let cu = dir.appendingPathComponent("theme-compare.png")
        try rep.representation(using: .png, properties: [:])?.write(to: cu)
        return outs + [cu]
    }

    private static func sampleBackground(size: CGSize, scale: CGFloat, dark: Bool) -> CGImage {
        let w = Int(size.width * scale), h = Int(size.height * scale)
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: scale, y: scale)
        let g = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = g
        (dark ? AnnotateTheme.hex(0x1B1D22) : AnnotateTheme.hex(0xE9ECF1)).setFill()
        CGRect(origin: .zero, size: size).fill()
        // A fake app window.
        let win = CGRect(x: 60, y: 40, width: 700, height: 410)
        (dark ? AnnotateTheme.hex(0x2A2D33) : .white).setFill()
        NSBezierPath(roundedRect: win, xRadius: 10, yRadius: 10).fill()
        (dark ? AnnotateTheme.hex(0x33363D) : AnnotateTheme.hex(0xF4F5F7)).setFill()
        CGRect(x: win.minX, y: win.maxY - 36, width: win.width, height: 26).fill()
        for (i, c) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
            AnnotateTheme.hex(UInt32(c)).setFill()
            NSBezierPath(ovalIn: CGRect(x: win.minX + 14 + CGFloat(i) * 18, y: win.maxY - 24, width: 11, height: 11)).fill()
        }
        let ink = dark ? NSColor(white: 0.9, alpha: 1) : NSColor(white: 0.15, alpha: 1)
        NSAttributedString(string: "Product intro", attributes: [.font: NSFont.systemFont(ofSize: 22, weight: .bold), .foregroundColor: ink])
            .draw(at: CGPoint(x: 160, y: 340))
        let muted = dark ? NSColor(white: 1, alpha: 0.14) : NSColor(white: 0, alpha: 0.09)
        for (i, wv) in [380.0, 460, 300, 420, 340].enumerated() {
            muted.setFill()
            NSBezierPath(roundedRect: CGRect(x: 160, y: 300 - CGFloat(i) * 26, width: wv, height: 10), xRadius: 5, yRadius: 5).fill()
        }
        AnnotateTheme.hex(0x3B82F6).setFill()
        NSBezierPath(roundedRect: CGRect(x: 166, y: 150, width: 120, height: 30), xRadius: 8, yRadius: 8).fill()
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()!
    }
}
