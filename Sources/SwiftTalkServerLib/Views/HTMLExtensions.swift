//
//  HTMLExtensions.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 09-02-2019.
//

import Foundation
import HTML
import WebServer


typealias Node = HTML.Node<STRequestEnvironment>

extension HTML.Node where I == STRequestEnvironment {
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
    
    static func hashedImg(classes: Class? = nil, src: String, alt: String = "", attributes: [String:String] = [:]) -> Node {
        return Node.withInput { deps in
            return Node.img(classes: classes, src: deps.hashedAssetName(src), alt: alt, attributes: attributes)
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
}

