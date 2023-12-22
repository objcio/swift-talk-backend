//
//  HTMLHelpers.swift
//  HTML
//
//  Created by Florian Kugler on 09-02-2019.
//

import Foundation


// This extension is from HTMLString: https://github.com/alexaubry/HTMLString
extension UnicodeScalar {
    /// Returns the decimal HTML entity for this Unicode scalar.
    public var htmlEscaped: String {
        return "&#" + String(value) + ";"
    }
    
    /// Escapes the scalar only if it needs to be escaped for Unicode pages.
    ///
    /// [Reference](http://wonko.com/post/html-escaping)
    fileprivate var escapingIfNeeded: String {
        switch value {
        case 33, 34, 36, 37, 38, 39, 43, 44, 60, 61, 62, 64, 91, 93, 96, 123, 125: return htmlEscaped
        default: return String(self)
        }
        
    }
}

extension String {
    var addingUnicodeEntities: String {
        var result = ""
        result.reserveCapacity(count)
        return unicodeScalars.reduce(into: result, { $0.append($1.escapingIfNeeded) })
    }
    
    public var escapeForAttributeValue: String {
        return self.replacingOccurrences(of: "\"", with: "&quot;")
    }
}

extension Dictionary where Key == String, Value == String {
    public var asAttributes: String {
        return isEmpty ? "" : " " + map { (k,v) in
            "\(k)=\"\(v.escapeForAttributeValue)\""
            }.joined(separator: " ")
    }
}

extension String {
    var xmlString: String {
        var result = ""
        result.reserveCapacity(count)
        for c in self {
            switch c {
            case "&": result.append("&amp;")
            case "\"": result.append("&quot;")
            case "'": result.append("&apos;")
            case "<": result.append("&lt;")
            case ">": result.append("&gt;")
            default: result.append(c)
            }
        }
        return result
    }
}

