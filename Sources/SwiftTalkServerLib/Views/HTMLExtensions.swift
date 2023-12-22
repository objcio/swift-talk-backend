//
//  HTMLExtensions.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 09-02-2019.
//

import Foundation
import Base
import HTML1
import WebServer
import CommonMark


typealias Node = HTML1.Node<STRequestEnvironment>

protocol LinkTarget {
    var absoluteString: String { get }
}
extension URL: LinkTarget {}
extension Route: LinkTarget {
    var absoluteString: String { return path }
}

extension HTML1.Node where I == STRequestEnvironment {
    static func hashedStylesheet(media: String = "all", href: String) -> Node {
        return Node.withInput { deps in
            return Node.stylesheet(media: media, href: deps.hashedAssetName(href))
        }
    }
    
    static func hashedScript(src: String) -> Node {
        return Node.withInput { deps in
            return Node.script(src: deps.hashedAssetName(src))
        }
    }
    
    static func hashedImg(class: Class? = nil, src: String, alt: String = "", attributes: [String:String] = [:]) -> Node {
        return Node.withInput { deps in
            return Node.img(class: `class`, src: deps.hashedAssetName(src), alt: alt, attributes: attributes)
        }
    }
    
    static func withCSRF(_ f: @escaping (CSRFToken) -> Node) -> Node {
        return .withInput { f($0.csrf) }
    }
    
    static func withSession(_ f: @escaping (Session?) -> Node) -> Node {
        return .withInput { f($0.session) }
    }
    
    static func withResourcePaths(_ f: @escaping ([URL]) -> Node) -> Node {
        return .withInput { f($0.resourcePaths) }
    }
    
    static func withRoute(_ f: @escaping (Route) -> Node) -> Node {
        return .withInput { f($0.route) }
    }

    static func link(to: Route, class: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return Node.a(class: `class`, href: to.path, attributes: attributes, children)
    }
    
    static func link(to: LinkTarget, class: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        return Node.a(class: `class`, href: to.absoluteString, attributes: attributes, children)
    }
    
    static func button(to route: Route, confirm: String? = "Are you sure?", class: Class? = nil, attributes: [String:String] = [:], _ children: [Node]) -> Node {
        var attrs = ["type": "submit"]
        if let c = confirm {
            attrs["data-confirm"] = c
        }
        return Node.withCSRF { csrf in
            Node.form(class: "button_to", action: route.path, method: .post, [
                Node.input(name: "csrf", id: "csrf", type: "hidden", attributes: ["value": csrf.string], []),
                Node.button(class: `class`, attributes: attrs, children)
                ])
        }
    }
    
    static func inlineSvg(class: Class? = nil, path: String, preserveAspectRatio: String? = nil, attributes: [String:String] = [:]) -> Node {
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
            if let c = `class` {
                a["class", default: ""] += c.class
            }
            // NOTE This has worked fine so far, but could be done with proper xml parsing if necessary
            let contents = try! String(contentsOf: name).replacingOccurrences(of: "<svg", with: "<svg " + a.asAttributes)
            return .raw(contents)
        }
    }
    
    static func markdown(_ string: String) -> Node {
        return Node.raw(CommonMark.Node(markdown: string).html(options: [.unsafe]))
    }
}

