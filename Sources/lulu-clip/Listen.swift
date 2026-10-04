import AppKit
import Carbon
import CoreGraphics
import Foundation
import LuluClipCore

enum Listen {
    static var outDir = resolveCacheDir(outFlag: nil)
    private static var hotKeyRef: EventHotKeyRef?
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
        let now = Date()
        if now.timeIntervalSince(lastFire) < 0.8 { return }
        lastFire = now
        log("hotkey")
        try? FileManager.default.removeItem(at: armURL)
        disarm()
        let dest = outDir
        Task.detached {
            let url = makeOutputURL(dir: dest, slug: displaySlug(app: "clip", title: "window"))
            do {
                try await Capture.captureInteractive(to: url)
                Listen.logPublic("wrote \(url.path)")
            } catch {
                Listen.logPublic("capture failed \(error)")
            }
        }
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
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        return InstallEventHandler(GetEventDispatcherTarget(), listenHotKeyHandler, 1, &spec, nil, nil)
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
    _: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    Listen.captureNow()
    return noErr
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
