import Foundation
import CommonMark

struct Chapter {
    var title: String
    var seconds: Int
}

struct Transcript {
    var html: String
    var chapters: [Chapter]

    init(_ markdown: String, highlighter: SwiftHighlighter = SwiftHighlighter()) throws {
        let blocks = CommonMark.Node(markdown: markdown).elements
        var chapters: [Chapter] = []
        var pendingTitle: String?
        var cueCounts: [Int: Int] = [:]
        let transformed = blocks.deepApply { (block: Block) -> [Block] in
            switch block {
            case let .heading(text, _):
                pendingTitle = text.deep { (inline: Inline) -> [String] in
                    switch inline {
                    case let .text(value), let .code(value): return [value]
                    default: return []
                    }
                }.joined()
                return [block]
            case let .paragraph(text):
                guard case let .text(value)? = text.first,
                      let time = Self.timePrefix(value) else { return [block] }
                if let title = pendingTitle {
                    chapters.append(Chapter(title: title, seconds: time.seconds))
                    pendingTitle = nil
                } else if chapters.isEmpty {
                    chapters.append(Chapter(title: "Introduction", seconds: time.seconds))
                }
                // Only transform leading paragraph timestamps, never Swift code or existing links.
                cueCounts[time.seconds, default: 0] += 1
                let count = cueCounts[time.seconds]!
                let anchor = "t-\(time.seconds)" + (count == 1 ? "" : "-\(count)")
                let link = Inline.html(text: "<a data-pagefind-ignore href=\"?t=\(time.seconds)#\(anchor)\" title=\"Play at \(time.label)\">\(time.label)</a>")
                let paragraph = CommonMark.Node(blocks: [.paragraph(text: [link, .text(text: time.remainder)] + text.dropFirst())]).html(options: [.unsafe])
                // The anchor belongs to the indexed passage, not its ignored timestamp label.
                return [.html(text: paragraph.replacingOccurrences(of: "<p>", with: "<p id=\"\(anchor)\">", options: .anchored))]
            default:
                return [block]
            }
        }
        // These are trusted, editorial Markdown files. Raw HTML preserves existing transcript images.
        html = try highlighter.render(transformed)
        self.chapters = chapters
    }

    static func timePrefix(_ text: String) -> (seconds: Int, label: String, remainder: String)? {
        let pattern = #"^(\d+):([0-5]\d)(?::([0-5]\d))?(?=\s|$)"#
        guard let match = text.range(of: pattern, options: .regularExpression) else { return nil }
        let label = String(text[match])
        let parts = label.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 || parts.count == 3, parts[0] < 1_000_000 else { return nil }
        let seconds = parts.reduce(0) { $0 * 60 + $1 }
        return (seconds, label, String(text[match.upperBound...]))
    }
}

func markdown(_ text: String) -> String {
    CommonMark.Node(markdown: text).html(options: [.unsafe])
}
