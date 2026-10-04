import CoreGraphics
import LuluClipCore
import Testing

@Test func didFrontmostChangeDetectsNewId() {
    #expect(didFrontmostChange(from: 1, to: 2))
    #expect(!didFrontmostChange(from: 1, to: 1))
    #expect(!didFrontmostChange(from: 1, to: nil))
}

@Test func preferredWindowPicksLargestForPid() {
    let windows = [
        WindowInfo(id: 1, app: "Cursor", title: "small", pid: 10, bounds: CGRect(x: 0, y: 0, width: 100, height: 100)),
        WindowInfo(id: 2, app: "Cursor", title: "large", pid: 10, bounds: CGRect(x: 0, y: 0, width: 800, height: 600)),
        WindowInfo(id: 3, app: "Safari", title: "other", pid: 11, bounds: CGRect(x: 0, y: 0, width: 2000, height: 2000)),
    ]
    #expect(preferredWindow(in: windows, pid: 10)?.id == 2)
}

@Test func matchingWindowsFiltersAppOrTitle() {
    let windows = [
        WindowInfo(id: 1, app: "OpenCode", title: "main", pid: 10, bounds: .zero),
        WindowInfo(id: 2, app: "Safari", title: "OpenCode docs", pid: 11, bounds: .zero),
        WindowInfo(id: 3, app: "Cursor", title: "lulu-clip", pid: 12, bounds: .zero),
    ]
    let hits = matchingWindows(windows, query: "opencode")
    #expect(hits.map(\.id) == [1, 2])
}

@Test func matchingWindowsEmptyQueryKeepsAll() {
    let windows = [
        WindowInfo(id: 1, app: "A", title: "", pid: 1, bounds: .zero),
    ]
    #expect(matchingWindows(windows, query: "  ").count == 1)
}

@Test func displaySlugStripsPunctuation() {
    #expect(displaySlug(app: "OpenCode", title: "Foo / Bar") == "opencode-foo-bar")
}

@Test func displaySlugFallsBackWhenEmpty() {
    #expect(displaySlug(app: "***", title: "") == "clip")
}
