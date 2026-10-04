import CoreGraphics
import Foundation

public struct WindowInfo: Equatable, Sendable {
    public var id: UInt32
    public var app: String
    public var title: String
    public var pid: Int32
    public var bounds: CGRect

    public init(id: UInt32, app: String, title: String, pid: Int32, bounds: CGRect) {
        self.id = id
        self.app = app
        self.title = title
        self.pid = pid
        self.bounds = bounds
    }
}

public func frontmostWindowID() -> UInt32? {
    guard let list = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
    ) as? [[String: Any]] else { return nil }
    for item in list {
        let layer = item[kCGWindowLayer as String] as? Int ?? -1
        guard layer == 0 else { continue }
        let bounds = item[kCGWindowBounds as String] as? [String: Any]
        let width = (bounds?["Width"] as? NSNumber)?.doubleValue ?? 0
        let height = (bounds?["Height"] as? NSNumber)?.doubleValue ?? 0
        guard width >= 80, height >= 80 else { continue }
        if let number = item[kCGWindowNumber as String] as? UInt32 {
            return number
        }
        if let number = item[kCGWindowNumber as String] as? Int {
            return UInt32(number)
        }
    }
    return nil
}

public func didFrontmostChange(from: UInt32, to: UInt32?) -> Bool {
    guard let to else { return false }
    return to != from
}

public func preferredWindow(in windows: [WindowInfo], pid: Int32) -> WindowInfo? {
    windows.filter { $0.pid == pid }.max {
        ($0.bounds.width * $0.bounds.height) < ($1.bounds.width * $1.bounds.height)
    }
}

public func matchingWindows(_ windows: [WindowInfo], query: String) -> [WindowInfo] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if q.isEmpty { return windows }
    return windows.filter {
        $0.app.localizedCaseInsensitiveContains(q) || $0.title.localizedCaseInsensitiveContains(q)
    }
}

public func displaySlug(app: String, title: String) -> String {
    let raw = title.isEmpty ? app : "\(app)-\(title)"
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
    let mapped = raw.lowercased().map { ch -> Character in
        String(ch).rangeOfCharacter(from: allowed) != nil ? ch : "-"
    }
    let collapsed = String(mapped)
        .split(separator: "-", omittingEmptySubsequences: true)
        .joined(separator: "-")
    if collapsed.isEmpty { return "clip" }
    return String(collapsed.prefix(48))
}
