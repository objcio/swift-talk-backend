//
//  CommonMarkRendering.swift
//  Bits
//
//  Created by Chris Eidhof on 21.12.18.
//

import Foundation
import CommonMark
import SourceKittenFramework

fileprivate enum Kind {
    case indent
    case other
    case keyword
    case identifier
    case typeIdentifier
    case attribute
    case number
    case string
    case comment
    case error
    
    var htmlClass: String? {
        switch self {
        case .indent: return nil
        case .other: return nil
        case .keyword: return "hljs-keyword"
        case .identifier: return "hljs-identifier"
        case .typeIdentifier: return "hljs-type"
        case .attribute: return "hljs-meta"
        case .number: return "hljs-number"
        case .string: return "hljs-string"
        case .comment: return "hljs-comment"
        case .error: return "hljs-error"
        }
    }
    
    init?(sourceKitType type: String) {
        switch type {
        case "source.lang.swift.syntaxtype.comment": self = .comment
        case "source.lang.swift.syntaxtype.argument": self = .identifier
        case "source.lang.swift.syntaxtype.attribute.builtin": self = .keyword
        case "source.lang.swift.syntaxtype.attribute.id": self = .attribute
        case "source.lang.swift.syntaxtype.buildconfig.id": self = .identifier
        case "source.lang.swift.syntaxtype.buildconfig.keyword": self = .keyword
        case "source.lang.swift.syntaxtype.comment.mark": self = .comment
        case "source.lang.swift.syntaxtype.comment.url": self = .comment
        case "source.lang.swift.syntaxtype.doccomment": self = .comment
        case "source.lang.swift.syntaxtype.doccomment.field": self = .comment
        case "source.lang.swift.syntaxtype.identifier": self = .identifier
        case "source.lang.swift.syntaxtype.keyword": self = .keyword
        case "source.lang.swift.syntaxtype.number": self = .number
        case "source.lang.swift.syntaxtype.parameter": self = .identifier
        case "source.lang.swift.syntaxtype.string": self = .string
        case "source.lang.swift.syntaxtype.string_interpolation_anchor": self = .string
        case "source.lang.swift.syntaxtype.typeidentifier": self = .typeIdentifier
        case "source.lang.swift.syntaxtype.objectliteral":
            return nil
        case "source.lang.swift.syntaxtype.placeholder":
            return nil
        default:
            return nil
        }
    }
}

extension String {
    func highlightSwift() -> String {
        guard let map = try? SyntaxMap(file: File(contents: self)) else { return self }
        var result: String = ""
        var previous = utf8.startIndex
        for token in map.tokens {
            let start = utf8.index(utf8.startIndex, offsetBy: token.offset)
            if start < previous { continue } // skip overlapping token, not sure why this happens
            result.append(contentsOf: self[previous..<start])
            let end = utf8.index(start, offsetBy: token.length)
            let cl = Kind(sourceKitType: token.type)?.htmlClass ?? ""
            result.append(contentsOf: "<span class=\"\(cl)\">" + self[start..<end] + "</span>")
            previous = end
        }
        result.append(contentsOf: self[previous...])
        return result
    }
}

extension CommonMark.Node {
    var highlightedHTML: String {
        let swiftCode: [String] = elements.flatMap { (el: Block) -> [String] in
            return el.deep(collect: { (block: Block) -> [String] in
                guard case let .codeBlock(text, "swift") = block else { return [] }
                return [text]
            })
        }
        let highlights = Dictionary(zip(swiftCode, swiftCode.map { $0.highlightSwift() }), uniquingKeysWith: { $1 })
        let els = elements.deepApply { (block: Block) in
            guard case let .codeBlock(text, "swift") = block, let highlighted = highlights[text] else { return [block] }
            return [Block.html(text: "<pre class=\"highlight\"><code class=\"swift\">\(highlighted)</code></pre>")]
        }
        return CommonMark.Node(blocks: els).html
    }
}

extension Block {
    fileprivate var highlightedHTML: [Block] {
        return deepApply { (block) -> [Block] in
            return [block]
        }
    }
}
