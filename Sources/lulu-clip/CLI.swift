import Foundation
import LuluClipCore

@main
struct LuluClipCLI {
    static func main() async {
        do {
            try await run(Array(CommandLine.arguments.dropFirst()))
        } catch let error as ClipError {
            fputs((error.localizedDescription) + "\n", stderr)
            exit(Int32(exitCode(error)))
        } catch {
            fputs(error.localizedDescription + "\n", stderr)
            exit(1)
        }
    }

    private static func run(_ args: [String]) async throws {
        guard let command = args.first else { throw ClipError.usage }
        switch command {
        case "listen":
            Listen.run(outDir: parseListenOut(Array(args.dropFirst())))
        case "-h", "--help", "help":
            print(Self.usage)
        default:
            throw ClipError.usage
        }
    }

    private static func exitCode(_ error: ClipError) -> Int {
        switch error {
        case .usage, .invalidRegion, .encodeFailed: return 1
        case .notFound: return 2
        case .ambiguous: return 3
        case .permission, .captureFailed, .listenDown: return 4
        case .cancelled: return 5
        case .waitTimeout: return 6
        }
    }

    private static let usage = """
    lulu-clip listen [--out dir]   # cmd+e only while $out/arm exists
    """

    private static func parseListenOut(_ args: [String]) -> URL {
        var out = resolveCacheDir(
            outFlag: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/lulu-clip").path
        )
        var i = 0
        while i < args.count {
            if args[i] == "--out", i + 1 < args.count {
                out = resolveCacheDir(outFlag: args[i + 1])
                i += 1
            }
            i += 1
        }
        return out
    }
}
