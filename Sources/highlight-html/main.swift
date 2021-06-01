import Foundation
import CommonMark
import SourceKittenFramework
import libcmark

let lines: AnyIterator<String> = AnyIterator { readLine(strippingNewline: false) }
let contents = lines.joined()
let nodes = CommonMark.Node(markdown: contents)
print(nodes.highlightedHTML)
