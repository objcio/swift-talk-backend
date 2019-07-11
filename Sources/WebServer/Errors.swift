//
//  Errors.swift
//  WebServer
//
//  Created by Florian Kugler on 08-02-2019.
//

import Foundation


public struct ServerError: LocalizedError {
    /// Private message for logging
    public let privateMessage: String
    /// Message shown to the user
    public let publicMessage: String
    
    public init(privateMessage: String, publicMessage: String = "Something went wrong, please try again.") {
        self.privateMessage = privateMessage
        self.publicMessage = publicMessage
    }
    
    public var errorDescription: String? {
        return "ServerError: \(privateMessage)"
    }
}

public struct AuthorizationError: Error { }

