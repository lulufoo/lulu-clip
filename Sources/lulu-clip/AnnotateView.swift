import AppKit
import Carbon
import LuluClipCore

/// One per screen. Selecting: snapshot + dim. Editing (active screen only): dim outside,
/// frozen pixels inside, shapes, selection chrome, toolbar, inline text field.
final class OverlayView: NSView, NSTextFieldDelegate {
    unowned let session: AnnotateSession
    private var selStart: CGPoint?
    private var toolbar: AnnotateToolbar?

    private enum Drag {
        case none
        case draw(CGPoint)
        case move(CGPoint, Markup)
        case resize(MarkupHandle, Markup)
        /// Move/resize the locked selection. Shapes move with the box on move; stay put on resize.
        case frame(FrameGrip, CGPoint, CGRect, [Markup])
    }
    private var drag = Drag.none {
        didSet { if case .none = drag { dragActive = false } else { dragActive = true } }
    }
    private var dragActive = false
    private var dragBefore: [Markup] = []

    private var textField: NSTextField?
    private var textShape: Markup?
    private var textIndex: Int?
    var isEditingText: Bool { textField != nil }
    var editingTextColor: Int? { textField != nil ? textShape?.color : nil }
    var editingTextSize: CGFloat? { textField != nil ? textShape?.fontSize : nil }

    init(frame: NSRect, session: AnnotateSession) {
        self.session = session
        super.init(frame: frame)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var scale: CGFloat { window?.screen?.backingScaleFactor ?? 2 }
    private var isActive: Bool { session.activeView === self }
    private var hitTolerance: CGFloat { 5 }

    override func resetCursorRects() {
        if !session.editing { addCursorRect(bounds, cursor: .crosshair) }
    }

    private func debugLog(_ s: @autoclosure () -> String) {
        if session.debug { session.log("debug " + s()) }
    }

    // MARK: drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        bounds.fill(using: .copy)
        let dim = NSColor.black.withAlphaComponent(0.35)
        if session.editing {
            guard isActive, let sel = session.selection, let shot = session.frozen else { return }
            let outside = NSBezierPath(rect: bounds)
            outside.append(NSBezierPath(rect: sel))
            outside.windingRule = .evenOdd
            dim.set(); outside.fill()
            if !session.liveFrame { NSGraphicsContext.current?.cgContext.draw(shot, in: sel) }
        } else {
            if let screen = window?.screen,
               let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
               let snap = session.snapshots[id] {
                NSGraphicsContext.current?.cgContext.draw(snap, in: bounds)
            }
            guard isActive, let sel = session.selection else {
                dim.set(); bounds.fill(using: .sourceOver)
                return
            }
            let path = NSBezierPath(rect: bounds)
            path.append(NSBezierPath(rect: sel))
            path.windingRule = .evenOdd
            dim.set(); path.fill()
        }
        guard let sel = session.selection else { return }

        drawSelectionFrame(sel, handles: !session.editing || session.tool == .select)
        AnnotateTheme.drawPill("\(px(sel.width)) × \(px(sel.height))", at: CGPoint(x: sel.minX, y: sel.maxY + 6), in: bounds, accent: true)

        guard session.editing, let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.clip(to: sel)
        for (i, m) in session.shapes.enumerated() where !(textField != nil && i == textIndex) {
            MarkupRenderer.draw(m, in: ctx)
        }
        if let d = session.draft { MarkupRenderer.draw(d, in: ctx) }
        ctx.restoreGState()

        if let i = session.selected, session.shapes.indices.contains(i), textField == nil {
            drawSelectionChrome(session.shapes[i])
            measure(session.shapes[i])
        } else if let d = session.draft {
            measure(d)
        }
    }

    /// 1.5pt accent frame with small accent corner/edge handles (visual only).
    private func drawSelectionFrame(_ sel: CGRect, handles: Bool = true) {
        AnnotateTheme.accent.setStroke()
        let border = NSBezierPath(rect: sel.insetBy(dx: -0.75, dy: -0.75))
        border.lineWidth = 1.5
        border.stroke()
        guard handles else { return }
        let pts = [CGPoint(x: sel.minX, y: sel.minY), CGPoint(x: sel.maxX, y: sel.minY),
                   CGPoint(x: sel.minX, y: sel.maxY), CGPoint(x: sel.maxX, y: sel.maxY),
                   CGPoint(x: sel.midX, y: sel.minY), CGPoint(x: sel.midX, y: sel.maxY),
                   CGPoint(x: sel.minX, y: sel.midY), CGPoint(x: sel.maxX, y: sel.midY)]
        for c in pts {
            let r = CGRect(x: c.x - 3.5, y: c.y - 3.5, width: 7, height: 7)
            let h = NSBezierPath(roundedRect: r, xRadius: 2, yRadius: 2)
            AnnotateTheme.accent.setFill(); h.fill()
            NSColor.white.setStroke(); h.lineWidth = 1.2; h.stroke()
        }
    }

    private func drawSelectionChrome(_ m: Markup) {
        if m.kind == .text {
            let p = NSBezierPath(rect: m.bounds.insetBy(dx: -3, dy: -3))
            p.lineWidth = 1
            p.setLineDash([4, 3], count: 2, phase: 0)
            AnnotateTheme.accent.setStroke(); p.stroke()
            return
        }
        for h in m.handles {
            let c = m.point(of: h)
            let r = CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: r).fill()
            AnnotateTheme.accent.setStroke()
            let p = NSBezierPath(ovalIn: r)
            p.lineWidth = 1.5
            p.stroke()
        }
    }

    private func px(_ v: CGFloat) -> Int { Int((v * scale).rounded()) }

    private func measure(_ m: Markup) {
        switch m.kind {
        case .line, .arrow:
            let dx = m.b.x - m.a.x, dy = m.b.y - m.a.y
            let len = Int((hypot(dx, dy) * scale).rounded())
            let text = dx == 0 || dy == 0 ? "\(len)px" : "\(len)px  (\(px(abs(dx)))×\(px(abs(dy))))"
            label(text, at: CGPoint(x: m.b.x + 8, y: m.b.y + 8))
        case .rect:
            let r = m.bounds
            label("\(px(r.width))×\(px(r.height))", at: CGPoint(x: r.maxX + 6, y: r.minY - 20))
        case .text:
            break
        }
    }

    private func label(_ s: String, at p: CGPoint) {
        AnnotateTheme.drawPill(s, at: p, in: bounds, accent: false)
    }

    // MARK: toolbar hooks

    func showToolbar() {
        toolbar = AnnotateToolbar(host: self)
        window?.invalidateCursorRects(for: self)
        refresh()
        window?.makeFirstResponder(self)
    }

    func refresh() {
        toolbar?.refresh()
        session.redraw()
    }

    func pick(_ tool: AnnotateSession.Tool) {
        commitText()
        session.tool = tool
        if tool != .select { session.selected = nil }
        refresh()
    }

    func undo() { commitText(); session.undo(); refresh() }
    func redo() { commitText(); session.redo(); refresh() }
    func finish() { commitText(); session.done() }

    func setColor(_ i: Int) {
        session.style.color = i
        if let f = textField {
            textShape?.color = i
            f.textColor = Palette.color(i)
            f.shadow = textShadow(i)
        } else if let s = session.selected {
            session.mutate { $0[s].color = i }
        }
        refresh()
    }

    func setWidth(_ i: Int) {
        session.style.widthIndex = i
        if let s = session.selected, session.shapes[s].kind != .text {
            session.mutate { $0[s].width = Palette.widths[i] }
        }
        refresh()
    }

    func setFont(_ i: Int) {
        session.style.fontIndex = i
        let size = Palette.fontSizes[i]
        if let f = textField {
            textShape?.fontSize = size
            f.font = AnnotateTheme.rounded(size)
            resizeTextField()
        } else if let s = session.selected, session.shapes[s].kind == .text {
            session.mutate {
                $0[s].fontSize = size
                let sz = MarkupRenderer.textSize($0[s].text, fontSize: size)
                $0[s].b = CGPoint(x: $0[s].a.x + sz.width, y: $0[s].a.y + sz.height)
            }
        }
        refresh()
    }

    private func newShape(_ kind: MarkupKind, at p: CGPoint) -> Markup {
        Markup(kind: kind, a: p, b: p, color: session.style.color,
               width: Palette.widths[session.style.widthIndex],
               fontSize: Palette.fontSizes[session.style.fontIndex])
    }

    // MARK: text

    private func textShadow(_ color: Int) -> NSShadow? {
        MarkupRenderer.textAttributes(color: color, fontSize: 12)[.shadow] as? NSShadow
    }

    private func beginText(_ shape: Markup, index: Int?) {
        commitText()
        let f = NSTextField(string: shape.text)
        f.isBordered = false
        f.isBezeled = false
        f.drawsBackground = false
        f.focusRingType = .none
        f.font = AnnotateTheme.rounded(shape.fontSize)
        f.textColor = Palette.color(shape.color)
        f.cell?.wraps = false
        f.cell?.isScrollable = true
        f.wantsLayer = true
        f.shadow = textShadow(shape.color)
        f.delegate = self
        textField = f
        textShape = shape
        textIndex = index
        session.selected = nil
        addSubview(f)
        resizeTextField()
        window?.makeFirstResponder(f)
        f.currentEditor()?.selectedRange = NSRange(location: (shape.text as NSString).length, length: 0)
        debugLog("text begin index=\(index.map(String.init) ?? "new")")
        refresh()
    }

    private func resizeTextField() {
        guard let f = textField, let shape = textShape else { return }
        f.sizeToFit()
        let w = max(f.frame.width + 8, 40)
        // NSTextField insets text by ~2pt; align its glyphs with the rendered text origin.
        f.frame = CGRect(x: shape.a.x - 2, y: shape.a.y, width: w, height: f.frame.height)
    }

    func controlTextDidChange(_ obj: Notification) { resizeTextField() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy sel: Selector) -> Bool {
        if sel == #selector(NSResponder.insertNewline(_:)) { commitText(); return true }
        if sel == #selector(NSResponder.cancelOperation(_:)) { cancelText(); return true }
        return false
    }

    private func endTextField() -> (NSTextField, Markup, Int?)? {
        guard let f = textField, let shape = textShape else { return nil }
        textField = nil
        textShape = nil
        let index = textIndex
        textIndex = nil
        f.delegate = nil
        f.removeFromSuperview()
        window?.makeFirstResponder(self)
        return (f, shape, index)
    }

    func commitText() {
        guard let (f, shape, index) = endTextField() else { return }
        let text = f.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            if let i = index { session.mutate { $0.remove(at: i) } }
        } else {
            var m = shape
            m.text = text
            let sz = MarkupRenderer.textSize(text, fontSize: m.fontSize)
            m.b = CGPoint(x: m.a.x + sz.width, y: m.a.y + sz.height)
            session.mutate {
                if let i = index { $0[i] = m } else { $0.append(m) }
            }
            session.selected = index ?? session.shapes.count - 1
        }
        debugLog("text commit len=\(text.count)")
        refresh()
    }

    private func cancelText() {
        _ = endTextField()
        refresh()
    }

    // MARK: mouse

    private func handleHit(_ p: CGPoint) -> MarkupHandle? {
        guard let i = session.selected, session.shapes.indices.contains(i) else { return nil }
        let m = session.shapes[i]
        return m.handles.first { h in let c = m.point(of: h); return hypot(c.x - p.x, c.y - p.y) <= 7 }
    }

    override func mouseMoved(with event: NSEvent) {
        guard session.editing, isActive, let sel = session.selection, !dragActive else { return }
        let p = convert(event.locationInWindow, from: nil)
        if toolbar?.main.frame.contains(p) == true || toolbar?.style.frame.contains(p) == true {
            NSCursor.arrow.set()
        } else if handleHit(p) != nil {
            NSCursor.pointingHand.set()
        } else if session.tool == .select, let g = SelectionFrame.grip(sel, at: p) {
            if g.isMove { NSCursor.openHand.set() }
            else if g.y == 0 { NSCursor.resizeLeftRight.set() }
            else if g.x == 0 { NSCursor.resizeUpDown.set() }
            else { NSCursor.crosshair.set() }
        } else if topmostMarkup(session.shapes, at: p, tolerance: hitTolerance) != nil {
            NSCursor.openHand.set()
        } else if sel.contains(p) {
            switch session.tool {
            case .select: NSCursor.openHand.set()
            case .text: NSCursor.iBeam.set()
            default: NSCursor.crosshair.set()
            }
        } else {
            (session.tool == .select ? NSCursor.openHand : NSCursor.arrow).set()
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        if session.editing {
            debugLog("mouseDown edit p=\(p) active=\(isActive) inSel=\(session.selection?.contains(p) ?? false) tool=\(session.tool)")
            guard isActive, let sel = session.selection else { return }
            if textField != nil { commitText(); return }
            dragBefore = session.shapes
            if let h = handleHit(p), let i = session.selected {
                drag = .resize(h, session.shapes[i])
                return
            }
            // The box only moves/resizes in hand (Select) mode.
            if session.tool == .select, let g = SelectionFrame.grip(sel, at: p),
               topmostMarkup(session.shapes, at: p, tolerance: hitTolerance) == nil || !g.isMove {
                beginFrameDrag(g, p, sel)
                return
            }
            if let i = topmostMarkup(session.shapes, at: p, tolerance: hitTolerance) {
                session.selected = i
                if event.clickCount == 2, session.shapes[i].kind == .text {
                    beginText(session.shapes[i], index: i)
                    return
                }
                drag = .move(p, session.shapes[i])
                NSCursor.closedHand.set()
                refresh()
                return
            }
            session.selected = nil
            guard sel.contains(p) else {
                if session.tool == .select { beginFrameDrag(.move, p, sel) } else { refresh() }
                return
            }
            switch session.tool {
            case .select:
                beginFrameDrag(.move, p, sel)
                return
            case .text:
                let size = Palette.fontSizes[session.style.fontIndex]
                beginText(newShape(.text, at: CGPoint(x: p.x, y: p.y - size * 0.6)), index: nil)
                return
            case .line:
                drag = .draw(p); session.draft = newShape(.line, at: p)
            case .arrow:
                drag = .draw(p); session.draft = newShape(.arrow, at: p)
            case .rect:
                drag = .draw(p); session.draft = newShape(.rect, at: p)
            }
            refresh()
        } else {
            guard !session.freezing else { return }
            session.beginSelection(on: self)
            selStart = p
            session.selection = CGRect(origin: p, size: .zero)
            session.redraw()
        }
    }

    private func beginFrameDrag(_ g: FrameGrip, _ p: CGPoint, _ sel: CGRect) {
        session.selected = nil
        drag = .frame(g, p, sel, session.shapes)
        session.liveFrame = true
        (g.isMove ? NSCursor.closedHand : NSCursor.crosshair).set()
        refresh()
    }

    private func clamp(_ p: CGPoint, to r: CGRect) -> CGPoint {
        CGPoint(x: min(max(p.x, r.minX), r.maxX), y: min(max(p.y, r.minY), r.maxY))
    }

    private func constrained(_ kind: MarkupKind, from s: CGPoint, to p: CGPoint) -> CGPoint {
        switch kind {
        case .line: return constrainHV(from: s, to: p)
        case .arrow: return constrain45(from: s, to: p)
        case .rect: return constrainSquare(from: s, to: p)
        case .text: return p
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let raw = convert(event.locationInWindow, from: nil)
        let shift = event.modifierFlags.contains(.shift)
        if session.editing {
            if case let .frame(g, start, orig, shapes) = drag {
                let r = SelectionFrame.apply(g, to: orig, dx: raw.x - start.x, dy: raw.y - start.y, bounds: bounds)
                session.selection = r
                if g.isMove {
                    let dx = r.minX - orig.minX, dy = r.minY - orig.minY
                    session.shapes = shapes.map { $0.offsetBy(dx: dx, dy: dy) }
                }
                toolbar?.layout()
                session.redraw()
                return
            }
            guard let sel = session.selection else { return }
            let p = clamp(raw, to: sel)
            switch drag {
            case .none, .frame:
                return
            case let .draw(start):
                guard var d = session.draft else { return }
                d.b = shift ? clamp(constrained(d.kind, from: start, to: p), to: sel) : p
                session.draft = d
                debugLog("drag edit p=\(d.b)")
            case let .move(start, orig):
                guard let i = session.selected else { return }
                session.shapes[i] = orig.offsetBy(dx: raw.x - start.x, dy: raw.y - start.y)
            case let .resize(h, orig):
                guard let i = session.selected else { return }
                var q = p
                if shift {
                    switch h {
                    case .a: q = constrained(orig.kind, from: orig.b, to: p)
                    case .b: q = constrained(orig.kind, from: orig.a, to: p)
                    case .edge: break
                    }
                }
                session.shapes[i] = orig.resized(h, to: q)
            }
            session.redraw()
        } else {
            guard let start = selStart else { return }
            let p = clamp(raw, to: bounds)
            session.selection = CGRect(x: min(start.x, p.x), y: min(start.y, p.y),
                                       width: abs(p.x - start.x), height: abs(p.y - start.y)).integral
            session.redraw()
        }
    }

    override func mouseUp(with event: NSEvent) {
        if session.editing {
            if case .draw = drag, let d = session.draft {
                let r = d.bounds
                let big = d.kind == .rect ? (r.width >= 3 && r.height >= 3) : d.length >= 3
                if big {
                    session.shapes.append(d)
                    session.selected = session.shapes.count - 1
                }
            }
            session.draft = nil
            if case .frame = drag {
                drag = .none
                session.refreeze()
                refresh()
                return
            }
            if dragActive { session.commit(from: dragBefore) }
            drag = .none
            refresh()
        } else {
            guard selStart != nil else { return }
            selStart = nil
            session.lockSelection()
        }
    }

    override func rightMouseDown(with event: NSEvent) { session.cancel() }

    // MARK: keys

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let cmd = flags.contains(.command)
        let shift = flags.contains(.shift)
        let step = (shift ? 10 : 1) / scale
        switch Int(event.keyCode) {
        case kVK_Escape: session.cancel(); return
        case kVK_Return, kVK_ANSI_KeypadEnter: finish(); return
        default: break
        }
        guard session.editing else { super.keyDown(with: event); return }
        switch Int(event.keyCode) {
        case kVK_ANSI_Z where cmd: shift ? redo() : undo(); return
        case kVK_ANSI_D where cmd: duplicate(); return
        case kVK_Delete, kVK_ForwardDelete: deleteSelected(); return
        case kVK_LeftArrow: nudge(-step, 0); return
        case kVK_RightArrow: nudge(step, 0); return
        case kVK_UpArrow: nudge(0, step); return
        case kVK_DownArrow: nudge(0, -step); return
        default: break
        }
        guard !cmd, let ch = event.charactersIgnoringModifiers?.lowercased() else { super.keyDown(with: event); return }
        switch ch {
        case "v": pick(.select)
        case "l": pick(.line)
        case "a": pick(.arrow)
        case "r", "b": pick(.rect)
        case "t": pick(.text)
        case "[": stepWidth(-1)
        case "]": stepWidth(1)
        default: super.keyDown(with: event)
        }
    }

    private func stepWidth(_ d: Int) {
        if let s = session.selected, session.shapes[s].kind == .text {
            let cur = Palette.fontSizes.firstIndex(of: session.shapes[s].fontSize) ?? session.style.fontIndex
            setFont(min(max(cur + d, 0), Palette.fontSizes.count - 1))
        } else if session.selected == nil, session.tool == .text {
            setFont(min(max(session.style.fontIndex + d, 0), Palette.fontSizes.count - 1))
        } else {
            let cur = session.selected.flatMap { Palette.widths.firstIndex(of: session.shapes[$0].width) } ?? session.style.widthIndex
            setWidth(min(max(cur + d, 0), Palette.widths.count - 1))
        }
    }

    private func nudge(_ dx: CGFloat, _ dy: CGFloat) {
        guard let i = session.selected else { return }
        session.mutate { $0[i] = $0[i].offsetBy(dx: dx, dy: dy) }
        refresh()
    }

    private func deleteSelected() {
        guard let i = session.selected else { return }
        session.mutate { $0.remove(at: i) }
        session.selected = nil
        refresh()
    }

    private func duplicate() {
        guard let i = session.selected else { return }
        let off: CGFloat = 10
        session.mutate { $0.append($0[i].offsetBy(dx: off, dy: -off)) }
        session.selected = session.shapes.count - 1
        refresh()
    }
}

