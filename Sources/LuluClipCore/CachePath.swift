import Foundation

public func resolveCacheDir(outFlag: String?) -> URL {
    let path = outFlag ?? (FileManager.default.currentDirectoryPath + "/.cache/lulu-clip")
    return URL(fileURLWithPath: path, isDirectory: true)
}

public func makeOutputURL(dir: URL, slug: String, now: Date = Date()) -> URL {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return dir.appendingPathComponent("\(formatter.string(from: now))-\(slug).png")
}
