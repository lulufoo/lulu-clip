import CoreGraphics
import Testing
@testable import LuluClipCore

@Test func lineHitTestUsesSegmentDistance() {
    let m = Markup(kind: .line, a: .zero, b: CGPoint(x: 100, y: 0), width: 2)
    #expect(m.hitTest(CGPoint(x: 50, y: 5)))
    #expect(!m.hitTest(CGPoint(x: 50, y: 10)))
    #expect(!m.hitTest(CGPoint(x: 120, y: 0)))
}

@Test func rectHitsEdgeNotInterior() {
    let m = Markup(kind: .rect, a: .zero, b: CGPoint(x: 100, y: 80), width: 2)
    #expect(m.hitTest(CGPoint(x: 0, y: 40)))
    #expect(m.hitTest(CGPoint(x: 50, y: 82)))
    #expect(!m.hitTest(CGPoint(x: 50, y: 40)))
}

@Test func topmostPicksLastShape() {
    let r = Markup(kind: .rect, a: .zero, b: CGPoint(x: 100, y: 100))
    let l = Markup(kind: .line, a: CGPoint(x: 0, y: 50), b: CGPoint(x: 0, y: 60))
    #expect(topmostMarkup([r, l], at: CGPoint(x: 0, y: 55)) == 1)
    #expect(topmostMarkup([r, l], at: CGPoint(x: 50, y: 50)) == nil)
}

@Test func rectEdgeResizeNormalizes() {
    let m = Markup(kind: .rect, a: CGPoint(x: 10, y: 10), b: CGPoint(x: 50, y: 30))
    let r = m.resized(.edge(x: 1, y: 0), to: CGPoint(x: 0, y: 999))
    #expect(r.bounds == CGRect(x: 0, y: 10, width: 10, height: 20))
    #expect(m.point(of: .edge(x: 0, y: 1)) == CGPoint(x: 30, y: 30))
}

@Test func constrainMath() {
    #expect(constrainHV(from: .zero, to: CGPoint(x: 10, y: 3)) == CGPoint(x: 10, y: 0))
    #expect(constrainHV(from: .zero, to: CGPoint(x: 2, y: -9)) == CGPoint(x: 0, y: -9))
    let d = constrain45(from: .zero, to: CGPoint(x: 10, y: 9))
    #expect(abs(d.x - d.y) < 0.001)
    let v = constrain45(from: .zero, to: CGPoint(x: 1, y: -20))
    #expect(v.x == 0 && abs(v.y + hypot(1, 20)) < 0.001)
    #expect(constrainSquare(from: .zero, to: CGPoint(x: -10, y: 4)) == CGPoint(x: -4, y: 4))
}

@Test func undoRedoStack() {
    var h = UndoHistory<[Int]>()
    var state = [1]
    h.record(state); state = [1, 2]
    h.record(state); state = [1, 2, 3]
    state = h.undo(current: state)!
    #expect(state == [1, 2])
    state = h.redo(current: state)!
    #expect(state == [1, 2, 3])
    state = h.undo(current: state)!
    h.record(state); state = [9]
    #expect(!h.canRedo)
    #expect(h.undo(current: state) == [1, 2])
}
