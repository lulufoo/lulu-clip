import CoreGraphics

/// Which part of the locked selection frame a drag grabbed.
/// `x`/`y` are -1 (min edge), 0 (none/middle), 1 (max edge); (0,0) = move whole frame.
public struct FrameGrip: Equatable, Sendable {
    public var x: Int
    public var y: Int
    public init(x: Int, y: Int) { self.x = x; self.y = y }
    public static let move = FrameGrip(x: 0, y: 0)
    public var isMove: Bool { x == 0 && y == 0 }
}

public enum SelectionFrame {
    /// Hit-test the frame chrome: 8 handles first (radius `handle`), then the border band (±`band`) = move.
    public static func grip(_ sel: CGRect, at p: CGPoint, handle: CGFloat = 7, band: CGFloat = 4) -> FrameGrip? {
        let xs: [(Int, CGFloat)] = [(-1, sel.minX), (0, sel.midX), (1, sel.maxX)]
        let ys: [(Int, CGFloat)] = [(-1, sel.minY), (0, sel.midY), (1, sel.maxY)]
        for (gx, x) in xs { for (gy, y) in ys where !(gx == 0 && gy == 0) {
            if abs(p.x - x) <= handle && abs(p.y - y) <= handle { return FrameGrip(x: gx, y: gy) }
        } }
        let outer = sel.insetBy(dx: -band, dy: -band), inner = sel.insetBy(dx: band, dy: band)
        if outer.contains(p) && !inner.contains(p) { return .move }
        return nil
    }

    /// Apply a drag of (dx, dy) to `orig` with `grip`, keeping it inside `bounds` and >= `minSize`.
    public static func apply(_ grip: FrameGrip, to orig: CGRect, dx: CGFloat, dy: CGFloat,
                             bounds: CGRect, minSize: CGFloat = 8) -> CGRect {
        if grip.isMove {
            let x = min(max(orig.minX + dx, bounds.minX), bounds.maxX - orig.width)
            let y = min(max(orig.minY + dy, bounds.minY), bounds.maxY - orig.height)
            return CGRect(x: x, y: y, width: orig.width, height: orig.height).integral
        }
        var minX = orig.minX, maxX = orig.maxX, minY = orig.minY, maxY = orig.maxY
        if grip.x < 0 { minX = min(max(orig.minX + dx, bounds.minX), maxX - minSize) }
        if grip.x > 0 { maxX = max(min(orig.maxX + dx, bounds.maxX), minX + minSize) }
        if grip.y < 0 { minY = min(max(orig.minY + dy, bounds.minY), maxY - minSize) }
        if grip.y > 0 { maxY = max(min(orig.maxY + dy, bounds.maxY), minY + minSize) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY).integral
    }
}
