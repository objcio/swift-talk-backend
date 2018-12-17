//
//  Helpers.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-08-2018.
//

import Foundation


struct ServerError: LocalizedError {
    /// Private message for logging
    let privateMessage: String
    /// Message shown to the user
    let publicMessage: String
    
    var errorDescription: String? {
        return "ServerError: \(privateMessage)"
    }
}

struct AuthorizationError: Error { }


func catchAndDisplayError<I: SwiftTalkInterpreter & HTML>(line: UInt = #line, file: StaticString = #file, _ f: () throws -> I) -> I {
    do {
        return try f()
    } catch {
        log(file: file, line: line, error)
        if let e = error as? ServerError {
            return .write(errorView(e.publicMessage), status: .internalServerError)
        } else if let _ = error as? AuthorizationError {
            return .write(errorView("You're not authorized to view this page. Please login and try again."), status: .unauthorized)
        } else {
            return .write(errorView("Something went wrong — please contact us if the problem persists."), status: .internalServerError)
        }
    }
}

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

extension Int {
    var padded: String {
        return self < 10 ? "0" + "\(self)" : "\(self)"
    }
}

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return dateFormatter
    }()
}

extension TimeInterval {
    private var hm: (Int, Int, Int) {
        let h = floor(self/(60*60))
        let m = floor(self.truncatingRemainder(dividingBy: 60*60)/60)
        let s = self.truncatingRemainder(dividingBy: 60).rounded()
        return (Int(h), Int(m), Int(s))
    }
    
    var minutes: String {
        let m = Int((self/60).rounded())
        return "\(m) min"
    }
    
    var hoursAndMinutes: String {
        let (hours, minutes, _) = hm
        if hours > 0 {
            return "\(Int(hours))h\(minutes.padded)min"
        } else { return "\(minutes)min" }
    }
    
    var timeString: String {
        let (hours, minutes, seconds) = hm
        if hours == 0 {
            return "\(minutes.padded):\(seconds.padded)"
        } else {
            return "\(hours):\(minutes.padded):\(seconds.padded)"
        }
    }
}

extension DateFormatter {
    convenience init(format: String) {
        self.init()
        self.locale = Locale(identifier: "en_US")
        self.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateFormat = format
    }
    
    static let withYear = DateFormatter(format: "MMM dd yyyy")
    
    /// e.g. "November 23, 2018"
    static let fullPretty = DateFormatter(format: "MMMM dd, yyyy")
    static let withoutYear = DateFormatter(format: "MMM dd")
}

extension Date {
    var pretty: String {
        let cal = NSCalendar.current
        if cal.component(.year, from: Date()) == cal.component(.year, from: self) {
            return DateFormatter.withoutYear.string(from: self)
        } else {
            return DateFormatter.withYear.string(from: self)
        }
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
        return .div(classes: "react-component", attributes: [
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

