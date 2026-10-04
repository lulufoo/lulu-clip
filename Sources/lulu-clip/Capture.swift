import AppKit
import Foundation
import LuluClipCore

enum Capture {
    static func requestScreenAccess() {
        _ = NSApplication.shared
        if CGPreflightScreenCaptureAccess() { return }
        _ = CGRequestScreenCaptureAccess()
    }

    static func captureInteractive(to url: URL) async throws {
        requestScreenAccess()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-x", "-t", "png", url.path]
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw ClipError.cancelled
            }
            if !FileManager.default.fileExists(atPath: url.path) {
                throw ClipError.cancelled
            }
        }.value
    }
}
