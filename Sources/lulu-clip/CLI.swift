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
        case "toolbar-preview":
            let rest = Array(args.dropFirst())
            let positional = rest.first { !$0.hasPrefix("--") && !(rest.firstIndex(of: $0).map { $0 > 0 && rest[$0 - 1] == "--primary" } ?? false) }
            let dir = positional.map { URL(fileURLWithPath: $0, isDirectory: true) }
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/lulu-clip/.work")
            if rest.contains("--compare") || rest.contains("--primary") {
                var themes: [(String, UInt32)] = [("indigo", 0x5B5BD6), ("teal", 0x14B8A6), ("amber", 0xF59E0B)]
                if let i = rest.firstIndex(of: "--primary"), i + 1 < rest.count,
                   let v = UInt32(rest[i + 1].trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) {
                    themes = [(String(format: "%06x", v), v)]
                }
                let picked = themes
                let outs = try await MainActor.run {
                    try AnnotateToolbar.renderThemeCompare(dir: dir, themes: picked.map { ($0.0, AnnotateTheme.hex($0.1)) })
                }
                outs.forEach { print($0.path) }
                return
            }
            for (name, dark) in [("preview-light.png", false), ("preview-dark.png", true)] {
                let out = dir.appendingPathComponent(name)
                try await MainActor.run { try AnnotateToolbar.renderPreview(to: out, dark: dark) }
                print(out.path)
            }
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
    lulu-clip toolbar-preview [dir]   # debug: previews (light + dark); --compare | --primary <hex> for theme candidates
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
