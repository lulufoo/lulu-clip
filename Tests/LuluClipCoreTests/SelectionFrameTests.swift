import CoreGraphics
import Testing
@testable import LuluClipCore

private let sel = CGRect(x: 100, y: 100, width: 200, height: 100)
private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

@Test func gripFindsCornerEdgeAndBorder() {
    #expect(SelectionFrame.grip(sel, at: CGPoint(x: 101, y: 199)) == FrameGrip(x: -1, y: 1))
    #expect(SelectionFrame.grip(sel, at: CGPoint(x: 300, y: 150)) == FrameGrip(x: 1, y: 0))
    #expect(SelectionFrame.grip(sel, at: CGPoint(x: 150, y: 102)) == .move)
    #expect(SelectionFrame.grip(sel, at: CGPoint(x: 150, y: 150)) == nil)
    #expect(SelectionFrame.grip(sel, at: CGPoint(x: 50, y: 50)) == nil)
}

@Test func moveKeepsSizeAndClampsToScreen() {
    #expect(SelectionFrame.apply(.move, to: sel, dx: 50, dy: -20, bounds: screen) == CGRect(x: 150, y: 80, width: 200, height: 100))
    #expect(SelectionFrame.apply(.move, to: sel, dx: 5000, dy: -5000, bounds: screen) == CGRect(x: 800, y: 0, width: 200, height: 100))
}

@Test func resizeCornerAndMinSize() {
    #expect(SelectionFrame.apply(FrameGrip(x: 1, y: 1), to: sel, dx: 30, dy: 10, bounds: screen) == CGRect(x: 100, y: 100, width: 230, height: 110))
    let r = SelectionFrame.apply(FrameGrip(x: -1, y: 0), to: sel, dx: 500, dy: 0, bounds: screen)
    #expect(r.width == 8 && r.maxX == 300)
}
