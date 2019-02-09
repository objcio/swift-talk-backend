//
//  HTML+Helpers.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 16-08-2018.
//

import Foundation
import CommonMark
import Base
import HTML
import WebServer


protocol LinkTarget {
    var absoluteString: String { get }
}
extension URL: LinkTarget {}
extension Route: LinkTarget {
    var absoluteString: String { return path }
}

extension HTML.Node where I == STRequestEnvironment {
    static func link(to: Route, classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return Node.a(classes: classes, href: to.path, attributes: attributes, children)
    }

    static func link(to: LinkTarget, classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return Node.a(classes: classes, href: to.absoluteString, attributes: attributes, children)
    }
    
    static func button(to route: Route, confirm: String? = "Are you sure?", classes: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
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
    
    static func inlineSvg(classes: Class? = nil, path: String, preserveAspectRatio: String? = nil, attributes: [String:String] = [:]) -> Node {
        // don't render inline svg's in tests
        if ProcessInfo.processInfo.environment.keys.contains("IDEiPhoneInternalTestBundleName") {
            return Node.none
        }
        return Node.withResourcePaths { resourcePaths in
            guard let name = resourcePaths.resolve("images/" + path) else {
                log(info: "Couldn't find svg")
                return .none
            }
            var a = attributes
            if let c = classes {
                a["class", default: ""] += c.classes
            }
            // NOTE This has worked fine so far, but could be done with proper xml parsing if necessary
            let contents = try! String(contentsOf: name).replacingOccurrences(of: "<svg", with: "<svg " + a.asAttributes)
            return .raw(contents)
    	}
    }
    
    static func markdown(_ string: String) -> Node {
        return Node.raw(CommonMark.Node(markdown: string)!.html)
    }
}

