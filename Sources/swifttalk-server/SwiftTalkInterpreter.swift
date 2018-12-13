//
//  SwiftTalkInterpreter.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import NIOHTTP1

protocol SwiftTalkInterpreter: Interpreter {
    static func writeFile(path: String) -> Self
    static func notFound(_ string: String) -> Self
    static func write(_ string: String, status: HTTPResponseStatus) -> Self
    static func write(_ html: Node, status: HTTPResponseStatus) -> Self
    static func write<I>(_ html: ANode<I>, input: I, status: HTTPResponseStatus) -> Self
    static func write(xml: ANode<()>, status: HTTPResponseStatus) -> Self
    static func write(json: Data, status: HTTPResponseStatus) -> Self

    static func redirect(path: String) -> Self
    static func redirect(to route: Route, headers: [String: String]) -> Self
    
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) throws -> Self) -> Self
    
    static func onSuccess<A>(promise: Promise<A?>, file: StaticString, line: UInt, message: String, do cont: @escaping (A) throws -> Self) -> Self
    static func onSuccess<A>(promise: Promise<A?>, file: StaticString, line: UInt, message: String, do cont: @escaping (A) throws -> Self, or: @escaping () throws -> Self) -> Self
    
    static func withPostBody(do cont: @escaping ([String:String]) -> Self) -> Self
    static func withPostBody(do cont: @escaping ([String:String]) -> Self, or: @escaping () -> Self) -> Self
    static func withPostBody(do cont: @escaping ([String:String]) throws -> Self) -> Self
    static func withPostBody(csrf: CSRFToken, do cont: @escaping ([String:String]) throws -> Self, or: @escaping () throws -> Self) -> Self
    static func withPostBody(csrf: CSRFToken, do cont: @escaping ([String:String]) throws -> Self) -> Self
}


extension SwiftTalkInterpreter {
    static func writeFile(path: String) -> Self {
        return .writeFile(path: path, maxAge: 60)
    }
    
    static func notFound(_ string: String = "Not found") -> Self {
        return .write(string, status: .notFound)
    }
    
    static func write(_ string: String, status: HTTPResponseStatus = .ok) -> Self {
        return .write(string, status: status, headers: [:])
    }
    
    static func write<I>(_ html: ANode<I>, input: I, status: HTTPResponseStatus = .ok) -> Self {
        return .write(html.htmlDocument(input: input))
    }
    
    static func write(xml: ANode<()>, status: HTTPResponseStatus = .ok) -> Self {
        return Self.write(xml.xmlDocument, status: .ok, headers: ["Content-Type": "application/rss+xml; charset=utf-8"])
    }
    
    static func write(json: Data, status: HTTPResponseStatus = .ok) -> Self {
        return Self.write(json, status: .ok, headers: ["Content-Type": "application/json"])
    }
    
    static func redirect(path: String) -> Self {
        return .redirect(path: path, headers: [:])
    }
    
    static func redirect(to route: Route, headers: [String: String] = [:]) -> Self {
        return .redirect(path: route.path, headers: headers)
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) -> Self) -> Self {
        return .withPostData { data in
            let result = String(data: data, encoding: .utf8)?.parseAsQueryPart
            return cont(result ?? [:])
        }
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) -> Self, or: @escaping () -> Self) -> Self {
        return .withPostData { data in
            let result = String(data: data, encoding: .utf8)?.parseAsQueryPart
            if let r = result {
                return cont(r)
            } else {
                return or()
            }
        }
    }
    
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError { try cont(value) }
        })
    }
    
    static func onSuccess<A>(promise: Promise<A?>, file: StaticString = #file, line: UInt = #line, message: String = "Something went wrong.", do cont: @escaping (A) throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError {
                guard let v = value else {
                    throw ServerError(privateMessage: "Expected non-nil value, but got nil (\(file):\(line)).", publicMessage: message)
                }
                return try cont(v)
            }
        })
    }
    
    static func onSuccess<A>(promise: Promise<A?>, file: StaticString = #file, line: UInt = #line, message: String = "Something went wrong.", do cont: @escaping (A) throws -> Self, or: @escaping () throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError {
                if let v = value {
                    return try cont(v)
                } else {
                    return try or()
                }
            }
        })
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) throws -> Self) -> Self {
        return .withPostBody { dict in
            return catchAndDisplayError { try cont(dict) }
        }
    }
    
    static func withPostBody(do cont: @escaping ([String:String]) throws -> Self, or: @escaping () throws -> Self) -> Self {
        return .withPostData { data in
            return catchAndDisplayError {
                // TODO instead of checking whether data is empty, we should check whether it was a post?
                if !data.isEmpty, let r = String(data: data, encoding: .utf8)?.parseAsQueryPart {
                    return try cont(r)
                } else {
                    return try or()
                }
            }
        }
    }
    
    static func withPostBody(csrf: CSRFToken, do cont: @escaping ([String:String]) throws -> Self, or: @escaping () throws -> Self) -> Self {
        return .withPostBody(do: { body in
            guard body["csrf"] == csrf.stringValue else {
                throw ServerError(privateMessage: "CSRF failure", publicMessage: "Something went wrong.")
            }
            return try cont(body)
        }, or: or)
    }
    
    static func withPostBody(csrf: CSRFToken, do cont: @escaping ([String:String]) throws -> Self) -> Self {
        return .withPostBody(do: { body in
            guard body["csrf"] == csrf.stringValue else {
                throw ServerError(privateMessage: "CSRF failure", publicMessage: "Something went wrong.")
            }
            return try cont(body)
        })
    }
    
    static func write(_ html: Node, status: HTTPResponseStatus = .ok) -> Self {
        return Self.write(html.htmlDocument(input: LayoutDependencies(hashedAssetName: { file in
            guard let remainder = file.drop(prefix: "/assets/") else { return file }
            let rep = assets.fileToHash[remainder]
            return rep.map { "/assets/" + $0 } ?? file
        })), status: status)
    }

}
