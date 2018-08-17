//
//  HTML+Helpers.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation
import CommonMark

extension Node {
    static func link(to route: Route, _ children: [Node], classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        return Node.a(classes: classes, attributes: attributes, children, href: route.path)
    }
    
    static func inlineSvg(path: String, preserveAspectRatio: String? = nil, classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        let name = resourcePaths.resolve("images/" + path)!
        var a = attributes
        if let c = classes {
            a["class", default: ""] += c.classes
        }
        let contents = try! String(contentsOf: name).replacingOccurrences(of: "<svg", with: "<svg " + a.asAttributes) // todo proper xml parsing?
        return .raw(contents)
    }
    
    static func markdown(_ string: String) -> Node {
        return Node.raw(CommonMark.Node(markdown: string)!.html)
    }
}

