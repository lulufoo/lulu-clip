import AppKit
import Carbon
import CoreGraphics
import Foundation
import LuluClipCore

enum Listen {
    static var outDir = resolveCacheDir(outFlag: nil)
    private static var hotKeyRef: EventHotKeyRef?
    private static var manualHotKeyRef: EventHotKeyRef?
    private static var handlerInstalled = false
    private static var statusItem: NSStatusItem?
    private static let menuTarget = MenuTarget()
    private static var eventTap: CFMachPort?
    private static var lastFire = Date.distantPast
    private static var armed = false

    static var isArmed: Bool { armed }

    private static var armURL: URL {
        outDir.appendingPathComponent("arm")
    }

    static func run(outDir: URL) {
        if !Thread.isMainThread {
            DispatchQueue.main.sync {
                run(outDir: outDir)
            }
            return
        }
        self.outDir = outDir
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        try? writeListenPid()
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()
        NSApp.activate(ignoringOtherApps: false)
        Capture.requestScreenAccess()
        log("preflight=\(CGPreflightScreenCaptureAccess())")
        installStatusItem()
        let manual = installManualHotKey()
        log("manual hotkey cmd+shift+e status=\(manual)")
        let tap = installEventTap()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        syncArmFromDisk()
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            syncArmFromDisk()
        }
        log("listen ready tap=\(tap) armed=\(armed) out=\(outDir.path)")
        fputs("listening: cmd+e armed only while \(armURL.path) exists\n", stderr)
        NSApp.run()
    }

    static func captureNow() {
        guard armed else { return }
        if MainActor.assumeIsolated({ AnnotateSession.isOpen }) { return }
        let now = Date()
        if now.timeIntervalSince(lastFire) < 0.8 { return }
        lastFire = now
        log("hotkey")
        try? FileManager.default.removeItem(at: armURL)
        disarm()
        let url = makeOutputURL(dir: outDir, slug: displaySlug(app: "clip", title: "window"))
        Capture.requestScreenAccess()
        if Thread.isMainThread {
            MainActor.assumeIsolated { AnnotateSession.start(url: url) { Listen.logPublic($0) } }
        } else {
            RunLoop.main.perform(inModes: [.common]) {
                MainActor.assumeIsolated { AnnotateSession.start(url: url) { Listen.logPublic($0) } }
            }
        }
    }

    /// User-initiated capture (⌘⇧E or menu). Ignores `arm`; never touches the arm file.
    // NSApp.run() lives inside a DispatchQueue.main.sync block (see run()), so the main
    // *queue* is occupied and main.async blocks never drain. Use the main run loop instead.
    static func captureManual() {
        RunLoop.main.perform(inModes: [.common]) {
            MainActor.assumeIsolated {
                if AnnotateSession.isOpen { log("manual ignored: session open"); return }
                let now = Date()
                if now.timeIntervalSince(lastFire) < 0.8 { return }
                lastFire = now
                log("manual hotkey")
                let url = makeOutputURL(dir: outDir, slug: displaySlug(app: "clip", title: "window"))
                Capture.requestScreenAccess()
                AnnotateSession.start(url: url, manual: true) { Listen.logPublic($0) }
            }
        }
    }

    static func openOutDir() { NSWorkspace.shared.open(outDir) }

    private static func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let img = NSImage(systemSymbolName: "viewfinder", accessibilityDescription: "LuluClip")
        img?.isTemplate = true
        item.button?.image = img
        item.button?.toolTip = "LuluClip"
        let menu = NSMenu()
        let shot = NSMenuItem(title: "截图", action: #selector(MenuTarget.capture), keyEquivalent: "e")
        shot.keyEquivalentModifierMask = [.command, .shift]
        let open = NSMenuItem(title: "打开截图文件夹", action: #selector(MenuTarget.openFolder), keyEquivalent: "")
        let quit = NSMenuItem(title: "退出 LuluClip", action: #selector(MenuTarget.quit), keyEquivalent: "q")
        for i in [shot, open, quit] { i.target = menuTarget }
        menu.addItem(shot); menu.addItem(open); menu.addItem(.separator()); menu.addItem(quit)
        item.menu = menu
        statusItem = item
        log("status item installed=\(item.button != nil)")
    }

    private static func installHandlerOnce() -> OSStatus {
        if handlerInstalled { return noErr }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let st = InstallEventHandler(GetEventDispatcherTarget(), listenHotKeyHandler, 1, &spec, nil, nil)
        if st == noErr { handlerInstalled = true }
        return st
    }

    private static func installManualHotKey() -> OSStatus {
        let h = installHandlerOnce()
        if h != noErr { return h }
        let id = EventHotKeyID(signature: OSType(0x6C636C70), id: 2)
        return RegisterEventHotKey(UInt32(kVK_ANSI_E), UInt32(cmdKey | shiftKey), id,
                                   GetEventDispatcherTarget(), 0, &manualHotKeyRef)
    }

    private static func syncArmFromDisk() {
        let shouldArm = FileManager.default.fileExists(atPath: armURL.path)
        if shouldArm {
            arm()
        } else {
            disarm()
        }
    }

    private static func arm() {
        if armed { return }
        let carbon = installHotKey()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        armed = true
        log("armed carbon=\(carbon) tap=\(eventTap != nil)")
    }

    private static func disarm() {
        if !armed { return }
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        armed = false
        log("disarmed")
    }

    @discardableResult
    private static func installHotKey() -> OSStatus {
        let hotKeyID = EventHotKeyID(signature: OSType(0x6C636C70), id: 1)
        let registered = RegisterEventHotKey(
            UInt32(kVK_ANSI_E),
            UInt32(cmdKey),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        if registered != noErr {
            return registered
        }
        return installHandlerOnce()
    }

    private static func installEventTap() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: listenEventTap,
            userInfo: nil
        ) else {
            return false
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    static func logPublic(_ message: String) {
        log(message)
    }

    private static func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        let url = outDir.appendingPathComponent("listen.log")
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: url)
        }
    }
}

private func listenHotKeyHandler(
    _: EventHandlerCallRef?,
    event: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    var hk = EventHotKeyID()
    if let event {
        GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                          nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
    }
    let st = event == nil ? -1 : 0
    Listen.logPublic("hotkey event id=\(hk.id) sig=\(String(format: "%08x", hk.signature)) st=\(st) armed=\(Listen.isArmed) busy=\(MainActor.assumeIsolated { AnnotateSession.isOpen })")
    if hk.id == 2 { Listen.captureManual() } else { Listen.captureNow() }
    return noErr
}

final class MenuTarget: NSObject {
    @objc func capture() { Listen.logPublic("menu capture"); Listen.captureManual() }
    @objc func openFolder() { Listen.openOutDir() }
    @objc func quit() { NSApp.terminate(nil) }
}

private func listenEventTap(
    _: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    _: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if Listen.isArmed, let tap = Listen.eventTapForEnable() {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }
    guard type == .keyDown, Listen.isArmed else {
        return Unmanaged.passUnretained(event)
    }
    let flags = event.flags
    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
    let command = flags.contains(.maskCommand)
    let extras = flags.contains(.maskShift) || flags.contains(.maskAlternate) || flags.contains(.maskControl)
    if command && !extras && keycode == Int64(kVK_ANSI_E) {
        Listen.captureNow()
        return nil
    }
    return Unmanaged.passUnretained(event)
}

extension Listen {
    fileprivate static func eventTapForEnable() -> CFMachPort? { eventTap }
}
