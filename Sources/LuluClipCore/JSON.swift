import Foundation

public struct WindowJSON: Encodable {
    public var id: UInt32
    public var app: String
    public var title: String
    public var pid: Int32
    public var bounds: BoundsJSON

    public init(_ window: WindowInfo) {
        id = window.id
        app = window.app
        title = window.title
        pid = window.pid
        bounds = BoundsJSON(window.bounds)
    }
}

public struct BoundsJSON: Encodable {
    public var x: Int
    public var y: Int
    public var w: Int
    public var h: Int

    public init(_ rect: CGRect) {
        x = Int(rect.origin.x.rounded())
        y = Int(rect.origin.y.rounded())
        w = Int(rect.size.width.rounded())
        h = Int(rect.size.height.rounded())
    }
}

public struct ListResult: Encodable {
    public var ok: Bool
    public var error: String?
    public var windows: [WindowJSON]

    public init(ok: Bool, error: String? = nil, windows: [WindowJSON]) {
        self.ok = ok
        self.error = error
        self.windows = windows
    }

    private enum CodingKeys: String, CodingKey {
        case ok, error, windows
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ok, forKey: .ok)
        try container.encodeIfPresent(error, forKey: .error)
        try container.encode(windows, forKey: .windows)
    }
}

public func encodeJSON<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    guard let text = String(data: data, encoding: .utf8) else {
        throw ClipError.encodeFailed
    }
    return text
}

public enum ClipError: Error, Equatable {
    case encodeFailed
    case notFound
    case ambiguous
    case captureFailed(String)
    case cancelled
    case permission
    case invalidRegion
    case usage
    case waitTimeout
    case listenDown
}

extension ClipError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .encodeFailed: return "json encode failed"
        case .notFound: return "no matching window"
        case .ambiguous: return "ambiguous window match"
        case .captureFailed(let reason): return reason
        case .cancelled: return "interactive capture cancelled"
        case .permission: return "screen recording permission missing"
        case .invalidRegion: return "invalid region"
        case .usage: return "usage"
        case .waitTimeout: return "timed out waiting for window switch"
        case .listenDown: return "LuluClip listen is not running"
        }
    }
}
