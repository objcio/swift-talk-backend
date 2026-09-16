import Foundation
import SwiftTalkStatic

let usage = """
Build the public Swift Talk archive from local content checkouts.

Run from the repository root:
  swift run --package-path StaticSite swift-talk-static \
    --data /path/to/swift-talk-static-data \
    --transcripts /path/to/episode-transcripts

Options:
  --data PATH          Directory containing episodes.json, collections.json, collaborators.json (required)
  --transcripts PATH   Directory containing episodeN.md (required)
  --output PATH        Generated site directory (default: _site)
  --assets PATH        Existing site assets (default: assets)
  --site-assets PATH   Static CSS and JavaScript (default: StaticSite/Assets)
  --base-url URL       Public site origin (default: https://talk.objc.io)
  --as-of ISO8601      Release cutoff in UTC (default: now)
  --pagefind PATH      Pagefind executable (default: StaticSite/node_modules/.bin/pagefind)
  --help               Print this help
"""

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments.contains("--help") {
        print(usage)
    } else {
        let allowed = ["--data", "--transcripts", "--output", "--assets", "--site-assets", "--base-url", "--as-of", "--pagefind"]
        var options: [String: String] = [:]
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard allowed.contains(key), index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--") else {
                throw BuildError("Unknown option or missing value: \(key)\n\n\(usage)")
            }
            guard options[key] == nil else { throw BuildError("Repeated option: \(key)") }
            options[key] = arguments[index + 1]
            index += 2
        }
        guard let data = options["--data"], let transcripts = options["--transcripts"] else {
            throw BuildError("--data and --transcripts are required.\n\n\(usage)")
        }
        guard let base = URL(string: options["--base-url"] ?? "https://talk.objc.io") else {
            throw BuildError("Invalid --base-url")
        }
        var asOf = Date()
        if let cutoff = options["--as-of"] {
            guard let date = ISO8601DateFormatter().date(from: cutoff) else {
                throw BuildError("--as-of must include a time and timezone, e.g. 2026-09-15T00:00:00Z")
            }
            asOf = date
        }
        let result = try buildSite(BuildConfiguration(
            data: URL(fileURLWithPath: data), transcripts: URL(fileURLWithPath: transcripts),
            assets: URL(fileURLWithPath: options["--assets"] ?? "assets"),
            siteAssets: URL(fileURLWithPath: options["--site-assets"] ?? "StaticSite/Assets"),
            output: URL(fileURLWithPath: options["--output"] ?? "_site"), baseURL: base, asOf: asOf,
            pagefind: URL(fileURLWithPath: options["--pagefind"] ?? "StaticSite/node_modules/.bin/pagefind")
        ))
        print("Built \(result.episodes) public episodes and transcripts, \(result.collections) collections → \(result.output.path)")
    }
} catch {
    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
    exit(1)
}
