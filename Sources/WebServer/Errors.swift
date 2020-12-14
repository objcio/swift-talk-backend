//
//  Errors.swift
//  WebServer
//
//  Created by Florian Kugler on 08-02-2019.
//

import Foundation
import NIOWrapper

public struct ServerError: LocalizedError {
    /// Private message for logging
    public let privateMessage: String
    /// Message shown to the user
    public let publicMessage: String
    /// The HTTP status code
    public let status: HTTPResponseStatus
    
    public init(privateMessage: String, publicMessage: String = "Something went wrong, please try again.", status: HTTPResponseStatus = .internalServerError) {
        self.privateMessage = privateMessage
        self.publicMessage = publicMessage
        self.status = status
    }
    
    public var errorDescription: String? {
        return "ServerError: \(privateMessage)"
    }
}

public struct AuthorizationError: Error { }

