import AppKit
import LuluClipCore
import Carbon
import Foundation
import ScreenCaptureKit
import UniformTypeIdentifiers

/// In-place selection + annotation on the live screen.
/// Nothing is written to the out dir until Done; then `<name>.png.part` → rename → `<name>.png`.
@MainActor
final class AnnotateSession {
    static var current: AnnotateSession?

    enum Tool { case select, line, arrow, rect, text }
    struct Style { var color = 0; var widthIndex = 0; var fontIndex = 1 }

    let url: URL
    let log: (String) -> Void
    /// User-initiated (⌘⇧E / menu bar): also copies to the pasteboard, and uses log lines
    /// that wait-png.sh ignores so an unrelated waiting agent is never cancelled/unbounded.
    let manual: Bool
    private var windows: [OverlayWindow] = []
    private var finished = false

    // Selection lives on one screen, in that view's local coords (bottom-left origin, points).
    weak var activeView: OverlayView?
    var selection: CGRect?
    var editing = false
    var freezing = false
    /// Selection pixels frozen at lock time (full backing resolution). Final PNG = frozen + marks.
    var frozen: CGImage?
    /// Debug: touch `<out>/debug` to log edit-mode mouse events.
    lazy var debug = FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent("debug").path)
    var tool: Tool = .select
    var style = Style()
    var shapes: [Markup] = []
    var selected: Int?
    var history = UndoHistory<[Markup]>()
    var draft: Markup?

    init(url: URL, manual: Bool = false, log: @escaping (String) -> Void) {
        self.url = url
        self.manual = manual
        self.log = log
    }

    static var isOpen: Bool { current != nil }

    static func start(url: URL, manual: Bool = false, log: @escaping (String) -> Void) {
        current?.cancel()
        let s = AnnotateSession(url: url, manual: manual, log: log)
        current = s
        s.open()
    }

    /// Whole-screen snapshots taken at ⌘E, before the overlay steals the mouse (keeps hover states).
    private(set) var snapshots: [CGDirectDisplayID: CGImage] = [:]

    private func open() {
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        for screen in NSScreen.screens {
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
            let f = screen.frame
            let tl = CGRect(x: f.minX, y: primaryTop - f.maxY, width: f.width, height: f.height)
            if let img = CGWindowListCreateImage(tl, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]) {
                snapshots[id] = img
                if debug {
                    let dir = url.deletingLastPathComponent().appendingPathComponent(".work")
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let f = dir.appendingPathComponent("snap-\(id).png")
                    if let d = CGImageDestinationCreateWithURL(f as CFURL, UTType.png.identifier as CFString, 1, nil) {
                        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
                    }
                    log("debug snapshot \(f.path)")
                }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        for screen in NSScreen.screens {
            let w = OverlayWindow(screen: screen, session: self)
            windows.append(w)
            w.orderFrontRegardless()
        }
        let mouse = NSEvent.mouseLocation
        let keyWin = windows.first { NSMouseInRect(mouse, $0.frame, false) } ?? windows.first
        keyWin?.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
    }

    func beginSelection(on view: OverlayView) {
        guard !editing else { return }
        if activeView !== view {
            activeView?.needsDisplay = true
            activeView = view
        }
        view.window?.makeKey()
    }

    func lockSelection() {
        guard !freezing, !editing else { return }
        guard let sel = selection, sel.width >= 4, sel.height >= 4,
              let view = activeView, let screen = view.window?.screen else {
            selection = nil
            redraw()
            return
        }
        freezing = true
        log(manual ? "manual editing" : "edit begin")
        let scale = screen.backingScaleFactor
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        let screenHeight = screen.frame.height
        _ = scale
        // Crop the selection from the ⌘E-time snapshot so hover states under the mouse are preserved.
        guard let full = snapshots[displayID],
              case let k = CGFloat(full.width) / screen.frame.width,
              let shot = full.cropping(to: CGRect(x: sel.minX * k, y: (screenHeight - sel.maxY) * k,
                                                  width: sel.width * k, height: sel.height * k).integral) else {
            close()
            log("capture failed freeze")
            return
        }
        snapshots.removeAll()
        frozen = shot
        freezing = false
        editing = true
        if debug { log("debug frozen \(shot.width)x\(shot.height)") }
        view.showToolbar()
        view.window?.makeKeyAndOrderFront(nil)
        redraw()
    }

    /// True while the locked frame is being moved/resized: the box shows the live screen.
    var liveFrame = false

    /// Re-capture `selection` from the live screen, below our overlay window (so dim/toolbar are excluded).
    func refreeze() {
        guard let sel = selection, let view = activeView, let win = view.window else { return }
        let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
        let g = CGRect(x: win.frame.minX + sel.minX, y: primaryTop - (win.frame.minY + sel.maxY),
                       width: sel.width, height: sel.height)
        if let img = CGWindowListCreateImage(g, .optionOnScreenBelowWindow, CGWindowID(win.windowNumber), [.bestResolution]) {
            frozen = img
            log("refrozen \(Int(sel.width))x\(Int(sel.height))")
        } else {
            log("refreeze failed")
        }
        liveFrame = false
        redraw()
    }

    func redraw() { windows.forEach { $0.contentView?.needsDisplay = true } }

    /// Records `before` for undo when the shapes actually changed.
    func commit(from before: [Markup]) {
        if shapes != before { history.record(before) }
    }

    func mutate(_ f: (inout [Markup]) -> Void) {
        let before = shapes
        f(&shapes)
        commit(from: before)
    }

    func undo() {
        if let prev = history.undo(current: shapes) { shapes = prev; selected = nil }
    }

    func redo() {
        if let next = history.redo(current: shapes) { shapes = next; selected = nil }
    }

    func cancel() {
        guard !finished else { return }
        close()
        log(manual ? "manual capture closed" : "capture failed cancelled")
    }

    func done() {
        guard !finished, editing, let sel = selection, let shot = frozen else { return }
        let shapes = self.shapes
        let url = self.url
        close()
        do {
            let image = try AnnotateSession.composite(shot, selection: sel, shapes: shapes)
            try AnnotateSession.writePNG(image, to: url)
            log("wrote \(url.path)")
            // After the atomic rename: one pasteboard item with path text, file URL and PNG data.
            let pb = NSPasteboard.general
            pb.clearContents()
            let item = NSPasteboardItem()
            item.setString(url.path, forType: .string)
            item.setString(url.absoluteString, forType: .fileURL)
            if let data = try? Data(contentsOf: url) { item.setData(data, forType: .png) }
            let ok = pb.writeObjects([item])
            log("clipboard path+file+png ok=\(ok) manual=\(manual)")
        } catch {
            log("capture failed \(error)")
        }
    }

    private func close() {
        finished = true
        NSCursor.pop()
        for w in windows { w.orderOut(nil); w.close() }
        windows.removeAll()
        if AnnotateSession.current === self { AnnotateSession.current = nil }
    }

    // MARK: capture / composite / write

    static func captureRect(_ sel: CGRect, displayID: CGDirectDisplayID, screenHeight: CGFloat, scale: CGFloat) async throws -> CGImage {
        // LuluClip's own overlay windows are excluded by the filter below.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw NSError(domain: "LuluClip", code: 1, userInfo: [NSLocalizedDescriptionKey: "display not found"])
        }
        let me = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: me, exceptingWindows: [])
        let config = SCStreamConfiguration()
        // sourceRect: display-local points, top-left origin.
        config.sourceRect = CGRect(x: sel.minX, y: screenHeight - sel.maxY, width: sel.width, height: sel.height)
        config.width = Int((sel.width * scale).rounded())
        config.height = Int((sel.height * scale).rounded())
        config.scalesToFit = false
        config.showsCursor = false
        config.captureResolution = .best
        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    static func composite(_ shot: CGImage, selection sel: CGRect, shapes: [Markup]) throws -> CGImage {
        let w = shot.width, h = shot.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw NSError(domain: "LuluClip", code: 2, userInfo: [NSLocalizedDescriptionKey: "context"])
        }
        ctx.draw(shot, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: CGFloat(w) / sel.width, y: CGFloat(h) / sel.height)
        ctx.translateBy(x: -sel.minX, y: -sel.minY)
        ctx.clip(to: sel)
        let k = CGFloat(w) / sel.width
        for m in shapes { MarkupRenderer.draw(m, in: ctx, shadowScale: k) }
        guard let out = ctx.makeImage() else {
            throw NSError(domain: "LuluClip", code: 3, userInfo: [NSLocalizedDescriptionKey: "makeImage"])
        }
        return out
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let part = URL(fileURLWithPath: url.path + ".part")
        try? FileManager.default.removeItem(at: part)
        guard let dest = CGImageDestinationCreateWithURL(part as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "LuluClip", code: 4, userInfo: [NSLocalizedDescriptionKey: "png dest"])
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "LuluClip", code: 5, userInfo: [NSLocalizedDescriptionKey: "png finalize"])
        }
        if rename(part.path, url.path) != 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }

}

final class OverlayWindow: NSWindow {
    init(screen: NSScreen, session: AnnotateSession) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        // Fully transparent pixels click through by default; keep every mouse event in the overlay.
        ignoresMouseEvents = false
        let view = OverlayView(frame: NSRect(origin: .zero, size: screen.frame.size), session: session)
        contentView = view
        initialFirstResponder = view
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

