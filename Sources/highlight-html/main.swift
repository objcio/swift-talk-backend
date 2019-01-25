import Foundation
import CommonMark
import SourceKittenFramework
import Ccmark

let lines: AnyIterator<String> = AnyIterator { readLine(strippingNewline: false) }
let contents = lines.joined()
guard let nodes = CommonMark.Node(markdown: contents) else { fatalError("Can't parse") }
print(nodes.highlightedHTML)
