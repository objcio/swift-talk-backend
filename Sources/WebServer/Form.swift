//
//  Form.swift
//  Base
//
//  Created by Florian Kugler on 08-02-2019.
//

import Foundation
import HTML

public typealias ValidationError = (field: String, message: String)

public struct Form<A, RE> {
    public typealias N = ANode<RE>
    public typealias Render = (A, [ValidationError]) -> N
    public typealias Parse = ([String:String]) -> A?
    private let _parse: Parse
    public let render: Render
    public init(parse: @escaping Parse, render: @escaping Render) {
        self._parse = parse
        self.render = render
    }
    
    public func parse(_ data: [String:String]) -> A? {
        return _parse(data)
    }
}

extension Form {
    public func wrap(_ f: @escaping (N) -> N) -> Form<A, RE> {
        return Form(parse: _parse, render: { value, err in
            f(self.render(value, err))
        })
    }
}


