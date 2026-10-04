import Foundation
import LuluClipCore
import Testing

@Test func makeOutputURLUsesSlugAndTimestamp() {
    let dir = URL(fileURLWithPath: "/tmp/lulu-clip-test", isDirectory: true)
    let date = Date(timeIntervalSince1970: 0)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    let url = makeOutputURL(dir: dir, slug: "opencode", now: date)
    #expect(url.lastPathComponent == "\(formatter.string(from: date))-opencode.png")
}

@Test func resolveCacheDirPrefersOutFlag() {
    let url = resolveCacheDir(outFlag: "/tmp/custom-cache")
    #expect(url.path == "/tmp/custom-cache")
}
