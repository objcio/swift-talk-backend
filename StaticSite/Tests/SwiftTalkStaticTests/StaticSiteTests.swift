import XCTest
@testable import SwiftTalkStatic

final class StaticSiteTests: XCTestCase {
    var root: URL!
    var config: BuildConfiguration!
    let fm = FileManager.default

    override func setUpWithError() throws {
        root = fm.temporaryDirectory.appendingPathComponent("SwiftTalkStaticTests-\(UUID())")
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        config = BuildConfiguration(data: root.appendingPathComponent("data"), transcripts: root.appendingPathComponent("transcripts"), assets: repo.appendingPathComponent("assets"), siteAssets: repo.appendingPathComponent("StaticSite/Assets"), output: root.appendingPathComponent("site"), baseURL: URL(string: "https://example.com")!, asOf: parseDate("2026-09-15T00:00:00Z")!)
        try fm.createDirectory(at: config.data, withIntermediateDirectories: true)
        try fm.createDirectory(at: config.transcripts, withIntermediateDirectories: true)
        try writeJSON([
            ["number": 1, "title": "A & B: Swift's Types", "synopsis": "A public episode.", "release_at": "2020-01-01T12:00:00", "media_duration": 120.0, "vimeo_id": 123456, "preview_vimeo_id": 999999, "subscription_only": true, "collections": ["swift"], "collaborators": ["chris"], "resources": [["title": "Code", "subtitle": "Sample project", "url": "https://example.org/code"]]],
            ["number": 2, "title": "A scheduled episode", "synopsis": "Future content.", "release_at": "2030-01-01T12:00:00", "media_duration": 120, "vimeo_id": 654321, "subscription_only": false, "collections": ["swift"], "collaborators": [], "resources": []]
        ], "episodes.json")
        try writeJSON([["id": "swift", "title": "Swift", "description": "A collection.", "position": 1, "public": true, "use_as_title_prefix": true]], "collections.json")
        try writeJSON([["id": "chris", "name": "Chris", "url": "https://example.org/", "role": "host"]], "collaborators.json")
        try "00:06 Hello, everyone.\n\n## Generics & Types\n\n01:05 Full public transcript.\n\n```swift\nlet value = a < b\n```\n".write(to: config.transcripts.appendingPathComponent("episode1.md"), atomically: true, encoding: .utf8)
        try "An orphan draft.".write(to: config.transcripts.appendingPathComponent("episode99.md"), atomically: true, encoding: .utf8)
    }

    override func tearDownWithError() throws { try fm.removeItem(at: root) }

    func writeJSON(_ value: Any, _ name: String) throws {
        try JSONSerialization.data(withJSONObject: value).write(to: config.data.appendingPathComponent(name))
    }

    func read(_ path: String) throws -> String {
        try String(contentsOf: config.output.appendingPathComponent(path), encoding: .utf8)
    }

    func testBuildPublishesFullContentWithoutAccounts() throws {
        let summary = try buildSite(config)
        XCTAssertEqual(summary.episodes, 1)
        XCTAssertEqual(summary.collections, 1)
        let page = try read("episodes/S01E1-a-b-swift-s-types/index.html")
        XCTAssertTrue(page.contains("player.vimeo.com/video/123456?dnt=1"))
        XCTAssertFalse(page.contains("999999"))
        XCTAssertTrue(page.contains("Full public transcript."))
        XCTAssertTrue(page.contains("<span class=\"hljs-keyword\">let</span>"))
        XCTAssertTrue(page.contains("&lt;"))
        XCTAssertTrue(page.contains("Swift: A &amp; B: Swift&#39;s Types"))
        XCTAssertTrue(page.contains("?t=65#transcript"))
        for path in ["/account", "/subscribe", "/login", "/subscription", "/playProgress"] {
            XCTAssertFalse(page.contains(path))
        }
        XCTAssertFalse(fm.fileExists(atPath: config.output.appendingPathComponent("transcripts/episode2.md").path))
        XCTAssertFalse(fm.fileExists(atPath: config.output.appendingPathComponent("transcripts/episode99.md").path))
        let json = try read("episodes.json")
        XCTAssertFalse(json.contains("subscription_only"))
        XCTAssertFalse(json.contains("preview_vimeo_id"))
        XCTAssertTrue(json.contains("https://example.com/transcripts/episode1.md"))
        XCTAssertTrue(try read("episodes/S01E01-a-b-swift-s-types/index.html").contains("location.search + location.hash"))
        XCTAssertTrue(try read("sitemap.xml").contains("https://example.com/episodes/S01E1-a-b-swift-s-types"))
        XCTAssertTrue(try read("episodes.rss").contains("Swift: A &amp; B: Swift&#39;s Types"))
    }

    func testMissingTranscriptFailsWithoutReplacingPreviousBuild() throws {
        try buildSite(config)
        let original = try read("index.html")
        try fm.removeItem(at: config.transcripts.appendingPathComponent("episode1.md"))
        XCTAssertThrowsError(try buildSite(config)) { error in
            XCTAssertTrue(String(describing: error).contains("Missing or empty transcript"))
        }
        XCTAssertEqual(try read("index.html"), original)
    }

    func testRebuildRemovesStaleOutputAndPreservesInputs() throws {
        try buildSite(config)
        try "stale".write(to: config.output.appendingPathComponent("stale.html"), atomically: true, encoding: .utf8)
        try buildSite(config)
        XCTAssertFalse(fm.fileExists(atPath: config.output.appendingPathComponent("stale.html").path))
        XCTAssertTrue(fm.fileExists(atPath: config.transcripts.appendingPathComponent("episode1.md").path))
    }

    func testRefusesToReplaceUnownedOutputOrInputs() throws {
        try fm.createDirectory(at: config.output, withIntermediateDirectories: true)
        XCTAssertThrowsError(try buildSite(config))
        config.output = root
        XCTAssertThrowsError(try buildSite(config))
        config.output = config.data.appendingPathComponent("nested")
        XCTAssertThrowsError(try buildSite(config))
    }

    func testDuplicateEpisodeNumbersFail() throws {
        let data = try Data(contentsOf: config.data.appendingPathComponent("episodes.json"))
        let episodes = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        try writeJSON([episodes[0], episodes[0]], "episodes.json")
        XCTAssertThrowsError(try buildSite(config)) { error in
            XCTAssertTrue(String(describing: error).contains("Duplicate episode numbers"))
        }
    }

    func testFailedAssetCopyLeavesPreviousOutputIntact() throws {
        try buildSite(config)
        let original = try read("index.html")
        config.siteAssets = root.appendingPathComponent("missing-assets")
        XCTAssertThrowsError(try buildSite(config))
        XCTAssertEqual(try read("index.html"), original)
    }

    func testTranscriptTimestampsAndChapterTitles() throws {
        let transcript = try Transcript("""
        00:06 Introduction.

        ## A `View` & **Layout**

        01:02:03 A later chapter.

        ```swift
        01:23 This must stay code
        ```

        An ordinary [01:23](https://example.com) link.

        <img src="https://example.com/diagram.png" style="max-width:20em">
        """)
        XCTAssertEqual(transcript.chapters.map(\.seconds), [6, 3723])
        XCTAssertEqual(transcript.chapters.map(\.title), ["Introduction", "A View & Layout"])
        XCTAssertTrue(transcript.html.contains("?t=3723#transcript"))
        XCTAssertTrue(transcript.html.contains("class=\"swift language-swift\""))
        XCTAssertFalse(transcript.html.contains("?t=83"))
        XCTAssertTrue(transcript.html.contains("<img src=\"https://example.com/diagram.png\""))
    }

    func testSwiftHighlightingPreservesEscapedUnicodeAndCode() throws {
        let source = "// café 🦉\nlet greeting = \"<strong>Hi & bye</strong>\"\nlet café: [String] = []\nif 2 < 3 { print(greeting) }\n"
        let html = try SwiftHighlighter().highlight(source)
        XCTAssertTrue(html.contains("hljs-comment"))
        XCTAssertTrue(html.contains("hljs-keyword"))
        XCTAssertTrue(html.contains("hljs-type"))
        XCTAssertTrue(html.contains("hljs-string"))
        XCTAssertTrue(html.contains("hljs-number"))
        XCTAssertFalse(html.contains("<strong>"))
        let withoutMarkup = html.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        XCTAssertEqual(withoutMarkup, source.escaped)
    }

    func testOnlySwiftFencesAreHighlightedIncludingNestedBlocks() throws {
        let transcript = try Transcript("""
        > ```swift
        > let value = 1
        > ```

        ```text
        let value = <example>
        ```
        """)
        XCTAssertTrue(transcript.html.contains("<span class=\"hljs-keyword\">let</span>"))
        XCTAssertTrue(transcript.html.contains("<code class=\"language-text\">let value = &lt;example&gt;"))
    }

    func testUnlistedVimeoHashIsPreserved() throws {
        var episode = try Content(data: config.data, transcripts: config.transcripts, asOf: config.asOf).episodes[0]
        episode.vimeoHash = "abc123"
        XCTAssertEqual(episode.embedURL, "https://player.vimeo.com/video/123456?dnt=1&h=abc123")
    }

    func testHistoricalLinksGetStaticRedirects() throws {
        let transcript = config.transcripts.appendingPathComponent("episode1.md")
        try "00:06 [An old title](/episodes/S01E01-networking?t=6) and [another](https://talk.objc.io/episodes/S01E1-another-title).".write(to: transcript, atomically: true, encoding: .utf8)
        try buildSite(config)
        for alias in ["S01E01-networking", "S01E1-another-title"] {
            XCTAssertTrue(try read("episodes/\(alias)/index.html").contains("/episodes/S01E1-a-b-swift-s-types"))
        }
    }

    func testMalformedThumbnailHasSafeFallback() throws {
        var episode = try Content(data: config.data, transcripts: config.transcripts, asOf: config.asOf).episodes[0]
        episode.pictureUrl = "https//i.vimeocdn.com/video/123_1920x1080?r=pad"
        XCTAssertEqual(episode.posterURL, "https://i.vimeocdn.com/video/123_1920x1080?r=pad")
        episode.pictureUrl = "invalid-relative-image"
        XCTAssertNil(episode.posterURL)
    }

    func testRejectsInvalidBaseURL() {
        for value in ["https://example.com/subdirectory", "file:///tmp/site", "https://example.com/?token=123"] {
            config.baseURL = URL(string: value)!
            XCTAssertThrowsError(try buildSite(config))
        }
    }
}
