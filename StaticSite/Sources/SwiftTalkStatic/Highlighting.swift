import Foundation
import CommonMark
import SourceKittenFramework

/// Uses the original site's SourceKit token classes and stylesheet. Tokens are
/// UTF-8 byte ranges, so Unicode and source text must survive HTML escaping intact.
final class SwiftHighlighter {
    private var cache: [String: String] = [:]

    func highlight(_ source: String) throws -> String {
        if let html = cache[source] { return html }
        let tokens = try SyntaxMap(file: File(contents: source)).tokens
        let bytes = Array(source.utf8)
        var result = ""
        var previous = 0
        for token in tokens {
            let start = Int(token.offset.value)
            let length = Int(token.length.value)
            guard start >= previous, start <= bytes.count, length >= 0, length <= bytes.count - start else { continue }
            let end = start + length
            result += String(decoding: bytes[previous..<start], as: UTF8.self).escaped
            let text = String(decoding: bytes[start..<end], as: UTF8.self).escaped
            if let cssClass = Self.cssClass(for: token.type) {
                result += "<span class=\"\(cssClass)\">\(text)</span>"
            } else {
                result += text
            }
            previous = end
        }
        result += String(decoding: bytes[previous...], as: UTF8.self).escaped
        cache[source] = result
        return result
    }

    func render(_ blocks: [Block]) throws -> String {
        let highlighted = try blocks.deepApply { (block: Block) throws -> [Block] in
            guard case let .codeBlock(source, language) = block,
                  language?.lowercased() == "swift" else { return [block] }
            return [.html(text: "<pre class=\"highlight\"><code class=\"swift language-swift\">\(try highlight(source))</code></pre>")]
        }
        return CommonMark.Node(blocks: highlighted).html(options: [.unsafe])
    }

    private static func cssClass(for kind: String) -> String? {
        let name = kind.replacingOccurrences(of: "source.lang.swift.syntaxtype.", with: "")
        if name.hasPrefix("comment") || name.hasPrefix("doccomment") { return "hljs-comment" }
        switch name {
        case "keyword", "attribute.builtin", "buildconfig.keyword": return "hljs-keyword"
        case "typeidentifier": return "hljs-type"
        case "attribute.id": return "hljs-meta"
        case "number": return "hljs-number"
        case "string", "string_interpolation_anchor": return "hljs-string"
        case "identifier", "argument", "parameter", "buildconfig.id": return "hljs-identifier"
        default: return nil
        }
    }
}
