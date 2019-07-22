//
//  HTML+Testing.swift
//  SwiftTalkTests
//
//  Created by Florian Kugler on 09-02-2019.
//

import Foundation
@testable import HTML

extension Element where I == () {
    // todo: we might want to check for forms as well
    public func linkTargets() -> [String] {
        guard name == "a", let href = attributes["href"] else { return children.flatMap { $0.linkTargets() } }
        return [href]
    }
    
    public func forms() -> [(action: String, inputs: [(String,String)])] {
        return children.flatMap { $0.forms() }
    }
    
    public func inputs() -> [(String,String)] {
        return children.flatMap { $0.inputs() }
    }
}

extension Node where I == () {
    // Searches for a's and forms
    public func linkTargets() -> [String] {
        switch self {
        case ._none:
            return []
        case let ._node(n):
            return n.linkTargets()
        case let ._withInput(f):
            return f(()).linkTargets()
        case ._text:
            return []
        case ._raw(_):
            return []
        }
    }
    
    public func forms() -> [(action: String, inputs: [(String,String)])] {
        switch self {
        case .none:
            return []
        case let .node(n) where n.name == "form":
            guard let a = n.attributes["action"] else { fatalError() }
            return [(action: a, inputs: n.inputs())] // todo a.inputs
        case .node(let n): return n.forms()
        case let .withInput(f):
            return f(()).forms()
        case .text:
            return []
        case .raw(_):
            return []
        }
    }
    
    public func inputs() -> [(String,String)] {
        switch self {
        case .none:
            return []
        case let .node(n) where n.name == "input":
            return [(n.attributes["name"] ?? "", n.attributes["value"] ?? "")]
        case .node(let n):
            return n.inputs()
        case let .withInput(f):
            return f(()).inputs()
        case .text:
            return []
        case .raw(_):
            return []
        }
    }
}


