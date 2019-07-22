//
//  Reader.swift
//  Backtrace
//
//  Created by Chris Eidhof on 22.07.19.
//

import Foundation

public struct Reader<Value, Result> {
    public let run: (Value) -> Result
    
    public init(_ run: @escaping (Value) -> Result) {
        self.run = run
    }
    
    public static func const(_ value: Result) -> Reader {
        return Reader { _ in value }
    }
}
