//
//  Helpers.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation
import Base
@_exported import ViewHelpers

extension Optional where Wrapped == Session {
    var premiumAccess: Bool {
        return self?.premiumAccess ?? false
    }
}

extension Double {
    var isInt: Bool {
        return floor(self) == self
    }
}

extension String {
    var asSlug: String {
        let allowed = CharacterSet.alphanumerics
        return components(separatedBy: allowed.inverted).filter { !$0.isEmpty }.joined(separator: "-").lowercased()
    }

    /// Inserts a non-breakable space before the last word (to prevent widows)
    var widont: [Node] {
        return [.text(self)] // todo
    }
}

extension String {
    func pluralize(_ number: Int) -> String {
        return number == 1 ? self : "\(self)s"
    }
}

func dollarAmount(cents: Int) -> String {
    if cents < 0 {
        let amount = String(format: "%.2f", Double(0-cents) / 100)
        return "- $\(amount)"
    } else {
        let amount = String(format: "%.2f", Double(cents) / 100)
        return "$\(amount)"
    }
}

struct ReactComponent<A: Encodable> {
    var name: String
    func build(_ value: A) -> Node {
        return .div(class: "react-component", attributes: [
            "data-params": json(value),
            "data-component": name
        ], [])
    }
}

fileprivate func json<A: Encodable>(_ value: A) -> String {
    let encoder = JSONEncoder()
    //    encoder.keyEncodingStrategy = .convertToSnakeCase // TODO doesn't compile on Linux (?)
    return try! String(data: encoder.encode(value), encoding: .utf8)!
}

struct EpisodeWithProgress {
    var episode: Episode
    var progress: Int?
    
    var watched: Bool {
        return Int(episode.mediaDuration) - (progress ?? 0) < 30
    }
}

extension Plan {
    var prettyInterval: String {
        switch  plan_interval_unit {
        case .months where plan_interval_length == 1:
            return "monthly"
        case .months where plan_interval_length == 12:
            return "yearly"
        default:
            return "every \(plan_interval_length) \(plan_interval_unit.rawValue)"
        }
    }
    
    var prettyDuration: String {
        switch  plan_interval_unit {
        case .days:
            return "\(plan_interval_length) Days"
        case .months:
            if plan_interval_length == 12 {
                return "One Year"
            } else if plan_interval_length == 1 {
                return "1 Month"
            } else {
                return "\(plan_interval_length) Months"
            }
        }
    }
}

