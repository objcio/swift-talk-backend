//
//  ResponseExtensions.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 08-02-2019.
//

import Foundation
import WebServer

extension WebServer.Response {
    static func redirect(to route: Route, headers: [String: String] = [:]) -> Self {
        return .redirect(path: route.path, headers: headers)
    }
}

extension Reader: FailableResponse where Result: WebServer.Response, Value == STRequestEnvironment {
    public static func renderError(_ error: Error) -> Reader<Value, Result> {
        if let e = error as? ServerError {
            return Reader { .write(html: errorView(e.publicMessage).ast(input: $0), status: .internalServerError) }
        } else if let _ = error as? AuthorizationError {
            return Reader { .write(html: errorView("You're not authorized to view this page. Please login and try again.").ast(input: $0), status: .unauthorized) }
        } else {
            return Reader { .write(html: errorView("Something went wrong — please contact us if the problem persists.").ast(input: $0), status: .internalServerError) }
        }
    }
}

