import Darwin
import Foundation

public func listenHomeDir() -> URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/lulu-clip")
}

public func listenPidURL() -> URL {
    listenHomeDir().appendingPathComponent("listen.pid")
}

public func listenInboxDir() -> URL {
    listenHomeDir().appendingPathComponent("inbox")
}

public struct ClipJob: Codable, Sendable {
    public var id: String
    public var op: String
    public var query: String?
    public var region: String?
    public var interactive: Bool
    public var frontmost: Bool
    public var outDir: String

    public init(
        id: String,
        op: String,
        query: String? = nil,
        region: String? = nil,
        interactive: Bool = false,
        frontmost: Bool = false,
        outDir: String
    ) {
        self.id = id
        self.op = op
        self.query = query
        self.region = region
        self.interactive = interactive
        self.frontmost = frontmost
        self.outDir = outDir
    }
}

public struct ClipJobResult: Codable, Sendable {
    public var exit: Int
    public var stdout: String
    public var stderr: String

    public init(exit: Int, stdout: String, stderr: String) {
        self.exit = exit
        self.stdout = stdout
        self.stderr = stderr
    }
}

public func isListenRunning() -> Bool {
    guard let text = try? String(contentsOf: listenPidURL(), encoding: .utf8),
          let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)),
          pid > 1
    else {
        return false
    }
    return kill(pid, 0) == 0
}

public func writeListenPid() throws {
    try FileManager.default.createDirectory(at: listenHomeDir(), withIntermediateDirectories: true)
    try "\(ProcessInfo.processInfo.processIdentifier)\n".write(to: listenPidURL(), atomically: true, encoding: .utf8)
}
