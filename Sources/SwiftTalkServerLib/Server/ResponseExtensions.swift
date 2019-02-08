//
//  ResponseExtensions.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 08-02-2019.
//

import Foundation
import WebServer

extension Response {
    static func redirect(to route: Route, headers: [String: String] = [:]) -> Self {
        return .redirect(path: route.path, headers: headers)
    }
}
