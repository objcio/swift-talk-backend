//
//  HighlightWrapper.swift
//
//  Created by Chris Eidhof on 07.01.19.
//

import Foundation
import CommonMark
import Base


fileprivate let highlighter: String? = {
    let fm = FileManager.default
    let possiblePaths = [
        ".build/release/highlight-html",
        ".build/debug/highlight-html"
    ]
    let c = fm.currentDirectoryPath
    for p in possiblePaths {
        let path = c + "/" + p
        if fm.fileExists(atPath: path) { return path }
    }
    return nil
}()

extension String {
    var markdownToHighlightedHTML: String {
        guard let h = highlighter else {
            log(error: "Can't find a highlighting binary")
            return CommonMark.Node(markdown: self)?.html(options: [.unsafe]) ?? ""
        }
        return Process.pipe(launchPath: h, self)
    }
}
