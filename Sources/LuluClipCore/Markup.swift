import CoreGraphics
import Foundation

/// Pure annotation model: shapes, handles, hit-testing, constrain math, undo history.
/// Coordinates are overlay-view points (bottom-left origin).
public enum MarkupKind: String, Sendable {
    case line, arrow, rect, text
}

/// Line/arrow endpoints `a`/`b`; rect edges `edge(x:y:)` with x,y in -1/0/1 (not both 0).
public enum MarkupHandle: Hashable, Sendable {
    case a, b
    case edge(x: Int, y: Int)
}

public struct Markup: Equatable, Sendable {
    public var kind: MarkupKind
    /// line/arrow: start; rect: one corner; text: bottom-left of the text box.
    public var a: CGPoint
    /// line/arrow: end; rect: opposite corner; text: top-right of the text box.
    public var b: CGPoint
    public var color: Int
    public var width: CGFloat
    public var fontSize: CGFloat
    public var text: String

    public init(kind: MarkupKind, a: CGPoint, b: CGPoint, color: Int = 0, width: CGFloat = 4,
                fontSize: CGFloat = 20, text: String = "") {
        self.kind = kind
        self.a = a
        self.b = b
        self.color = color
        self.width = width
        self.fontSize = fontSize
        self.text = text
    }

    public var bounds: CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
    }

    public var length: CGFloat { hypot(b.x - a.x, b.y - a.y) }

    public func offsetBy(dx: CGFloat, dy: CGFloat) -> Markup {
        var m = self
        m.a = CGPoint(x: a.x + dx, y: a.y + dy)
        m.b = CGPoint(x: b.x + dx, y: b.y + dy)
        return m
    }

    public var handles: [MarkupHandle] {
        switch kind {
        case .line, .arrow:
            return [.a, .b]
        case .rect:
            return [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)].map { .edge(x: $0.0, y: $0.1) }
        case .text:
            return []
        }
    }

    public func point(of handle: MarkupHandle) -> CGPoint {
        switch handle {
        case .a: return a
        case .b: return b
        case let .edge(x, y):
            let r = bounds
            let px = x < 0 ? r.minX : (x > 0 ? r.maxX : r.midX)
            let py = y < 0 ? r.minY : (y > 0 ? r.maxY : r.midY)
            return CGPoint(x: px, y: py)
        }
    }

    public func resized(_ handle: MarkupHandle, to p: CGPoint) -> Markup {
        var m = self
        switch handle {
        case .a: m.a = p
        case .b: m.b = p
        case let .edge(x, y):
            let r = bounds
            var minX = r.minX, maxX = r.maxX, minY = r.minY, maxY = r.maxY
            if x < 0 { minX = p.x } else if x > 0 { maxX = p.x }
            if y < 0 { minY = p.y } else if y > 0 { maxY = p.y }
            m.a = CGPoint(x: min(minX, maxX), y: min(minY, maxY))
            m.b = CGPoint(x: max(minX, maxX), y: max(minY, maxY))
        }
        return m
    }

    public func hitTest(_ p: CGPoint, tolerance: CGFloat = 5) -> Bool {
        let t = tolerance + width / 2
        switch kind {
        case .line, .arrow:
            return distanceToSegment(p, a, b) <= t
        case .rect:
            let r = bounds
            guard r.insetBy(dx: -t, dy: -t).contains(p) else { return false }
            let inner = r.insetBy(dx: t, dy: t)
            return inner.isEmpty || inner.isNull || !inner.contains(p)
        case .text:
            return bounds.insetBy(dx: -3, dy: -3).contains(p)
        }
    }
}

/// Index of the topmost (last drawn) shape under `p`.
public func topmostMarkup(_ shapes: [Markup], at p: CGPoint, tolerance: CGFloat = 5) -> Int? {
    shapes.indices.reversed().first { shapes[$0].hitTest(p, tolerance: tolerance) }
}

public func distanceToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = b.x - a.x, dy = b.y - a.y
    let len2 = dx * dx + dy * dy
    guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
    let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
    return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
}

/// Shift for lines: horizontal or vertical.
public func constrainHV(from s: CGPoint, to p: CGPoint) -> CGPoint {
    abs(p.x - s.x) >= abs(p.y - s.y) ? CGPoint(x: p.x, y: s.y) : CGPoint(x: s.x, y: p.y)
}

/// Shift for arrows: snap to 0/45/90… degrees, keeping length.
public func constrain45(from s: CGPoint, to p: CGPoint) -> CGPoint {
    let dx = p.x - s.x, dy = p.y - s.y
    let len = hypot(dx, dy)
    guard len > 0 else { return p }
    let step = CGFloat.pi / 4
    let k = Int((atan2(dy, dx) / step).rounded())
    let ux: [CGFloat] = [1, 0.70710678, 0, -0.70710678, -1, -0.70710678, 0, 0.70710678]
    let uy: [CGFloat] = [0, 0.70710678, 1, 0.70710678, 0, -0.70710678, -1, -0.70710678]
    let i = ((k % 8) + 8) % 8
    return CGPoint(x: s.x + ux[i] * len, y: s.y + uy[i] * len)
}

/// Shift for rects: square.
public func constrainSquare(from s: CGPoint, to p: CGPoint) -> CGPoint {
    let dx = p.x - s.x, dy = p.y - s.y
    let side = min(abs(dx), abs(dy))
    return CGPoint(x: s.x + (dx < 0 ? -side : side), y: s.y + (dy < 0 ? -side : side))
}

/// Snapshot undo/redo stack.
public struct UndoHistory<T> {
    public private(set) var past: [T] = []
    public private(set) var future: [T] = []
    public init() {}
    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }
    /// Call with the state *before* a mutation.
    public mutating func record(_ before: T) {
        past.append(before)
        future.removeAll()
    }
    public mutating func undo(current: T) -> T? {
        guard let prev = past.popLast() else { return nil }
        future.append(current)
        return prev
    }
    public mutating func redo(current: T) -> T? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        return next
    }
}
