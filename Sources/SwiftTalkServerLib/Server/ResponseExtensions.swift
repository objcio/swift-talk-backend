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

extension Reader where Result: ResponseRequiringEnvironment, Value == STRequestEnvironment, Result.Env == Value {
    static func renderError(_ error: Error) -> Reader<Value, Result> {
        if let e = error as? ServerError {
            return .const(.write(html: errorView(e.publicMessage), status: .internalServerError))
        } else if let _ = error as? AuthorizationError {
            return .const(.write(html: errorView("You're not authorized to view this page. Please login and try again."), status: .unauthorized))
        } else {
            return .const(.write(html: errorView("Something went wrong — please contact us if the problem persists."), status: .internalServerError))
        }
    }
}

