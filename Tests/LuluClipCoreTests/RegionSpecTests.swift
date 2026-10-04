import CoreGraphics
import LuluClipCore
import Testing

@Test func parseQuadrant() throws {
    #expect(try parseRegionSpec("bottom-left") == .quadrant(.bottomLeft))
}

@Test func parseRect() throws {
    #expect(try parseRegionSpec("10,20,30,40") == .rect(x: 10, y: 20, width: 30, height: 40))
}

@Test func parseRejectsBadInput() {
    #expect(throws: RegionParseError.invalid) {
        try parseRegionSpec("left")
    }
    #expect(throws: RegionParseError.invalid) {
        try parseRegionSpec("1,2,3")
    }
    #expect(throws: RegionParseError.invalid) {
        try parseRegionSpec("1,2,0,4")
    }
}

@Test func cropBottomLeft() {
    let rect = cropRect(imageSize: CGSize(width: 100, height: 80), spec: .quadrant(.bottomLeft))
    #expect(rect == CGRect(x: 0, y: 40, width: 50, height: 40))
}

@Test func cropRectClipsToImage() {
    let rect = cropRect(
        imageSize: CGSize(width: 100, height: 80),
        spec: .rect(x: 90, y: 70, width: 50, height: 50)
    )
    #expect(rect == CGRect(x: 90, y: 70, width: 10, height: 10))
}
