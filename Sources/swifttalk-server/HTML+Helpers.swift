//
//  HTML+Helpers.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation
import CommonMark

protocol LinkTarget {
    var absoluteString: String { get }
}
extension URL: LinkTarget {}
extension Route: LinkTarget {
    var absoluteString: String { return path }
}

extension ANode where I == RequestEnvironment {
    static func link(to: Route, classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return Node.a(classes: classes, attributes: attributes, children, href: to.path)
    }

    static func link(to: LinkTarget, classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return Node.a(classes: classes, attributes: attributes, children, href: to.absoluteString)
    }
    
    static func button(to route: Route, _ children: [Node], classes: Class? = nil, attributes: [String:String] = [:], confirm: String? = "Are you sure?") -> Node {
        var attrs = ["type": "submit"]
        if let c = confirm {
            attrs["data-confirm"] = c
        }
        return Node.withCSRF { csrf in
            Node.form(classes: "button_to", action: route.path, method: .post, [
                Node.input(name: "csrf", id: "csrf", type: "hidden", attributes: ["value": csrf.stringValue], []),
                Node.button(classes: classes, attributes: attrs, children)                
            ])
        }
    }
    
    static func inlineSvg(path: String, preserveAspectRatio: String? = nil, classes: Class? = nil, attributes: [String:String] = [:]) -> Node {
        let name = resourcePaths.resolve("images/" + path)!
        var a = attributes
        if let c = classes {
            a["class", default: ""] += c.classes
        }
        // NOTE This has worked fine so far, but could be done with proper xml parsing if necessary
        let contents = try! String(contentsOf: name).replacingOccurrences(of: "<svg", with: "<svg " + a.asAttributes)
        return .raw(contents)
    }
    
    static func markdown(_ string: String) -> Node {
        return Node.raw(CommonMark.Node(markdown: string)!.html)
    }
}

