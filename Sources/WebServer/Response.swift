//
//  SwiftTalkInterpreter.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import Base
import NIOWrapper
import HTML
import Database
import Promise


public protocol Response: NIOWrapper.Response {
    static func write(_ string: String, status: HTTPResponseStatus) -> Self
    static func write(html: Node<()>, status: HTTPResponseStatus) -> Self
    static func write(rss: Node<()>, status: HTTPResponseStatus) -> Self
    static func write(json: Data, status: HTTPResponseStatus) -> Self
}

extension NIOInterpreter: Response {}

public protocol FailableResponse {
    static func renderError(_ error: Error) -> Self
}

public protocol ResponseRequiringEnvironment: Response {
    associatedtype Env: RequestEnvironment
    static func write(html: Node<Env>, status: HTTPResponseStatus) -> Self
    static func withCSRF(_ cont: @escaping (CSRFToken) -> Self) -> Self
    static func withSession(_ cont: @escaping (Env.S?) -> Self) -> Self
    static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) -> Self) -> Self
}


extension Response {
    public static func writeFile(path: String, maxAge: UInt64? = 60) -> Self {
        return .writeFile(path: path, maxAge: maxAge)
    }
    
    public static func write(_ string: String, status: HTTPResponseStatus = .ok) -> Self {
        return .write(string, status: status, headers: ["Content-Type": "text/plain; charset=utf-8"])
    }
    
    public static func write(html: Node<()>, status: HTTPResponseStatus = .ok) -> Self {
        return .write(html.htmlDocument(input: ()), status: status, headers: ["Content-Type": "text/html; charset=utf-8"])
    }
    
    public static func write(rss: Node<()>, status: HTTPResponseStatus = .ok) -> Self {
        return .write(rss.xmlDocument, status: status, headers: ["Content-Type": "application/rss+xml; charset=utf-8"])
    }
    
    public static func write(json: Data, status: HTTPResponseStatus = .ok) -> Self {
        return .write(json, status: status, headers: ["Content-Type": "application/json"])
    }
}

extension Response where Self: FailableResponse {
    public static func onSuccess<A>(promise: Promise<A?>, file: StaticString = #file, line: UInt = #line, message: String = "Something went wrong.", do cont: @escaping (A) throws -> Self) -> Self {
        return onSuccess(promise: promise, file: file, line: line, do: cont, else: {
            throw ServerError(privateMessage: "Expected non-nil value, but got nil (\(file):\(line)).", publicMessage: message)
        })
    }
    
    public static func onSuccess<A>(promise: Promise<A?>, file: StaticString = #file, line: UInt = #line, do cont: @escaping (A) throws -> Self, else: @escaping () throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError {
                if let v = value {
                    return try cont(v)
                } else {
                    return try `else`()
                }
            }
        })
    }
    
    public static func onCompleteOrCatch<A>(promise: Promise<A>, do cont: @escaping (A) throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError { try cont(value) }
        })
    }

    public static func catchAndDisplayError(line: UInt = #line, file: StaticString = #file, _ f: () throws -> Self) -> Self {
        do {
            return try f()
        } catch {
            log(file: file, line: line, error)
            return .renderError(error)
        }
    }
}

extension ResponseRequiringEnvironment where Self: FailableResponse {
    public static func query<A>(_ query: Query<A>, _ cont: @escaping (A) throws -> Self) -> Self {
        return Self.execute(query) { (result: Either<A, Error>) in
            catchAndDisplayError {
                switch result {
                case let .left(value): return try cont(value)
                case let .right(err): throw err
                }
            }
        }
    }
    
    public static func query<A>(_ q: Query<A>?, or: @autoclosure () -> A, _ cont: @escaping (A) -> Self) -> Self {
        if let x = q {
            return query(x, cont)
        } else {
            return cont(or())
        }
    }
    
    public static func expectedPost() throws -> Self {
        throw ServerError(privateMessage: "Expected POST", publicMessage: "Something went wrong.")
    }

    public static func verifiedPost(do cont: @escaping ([String:String]) throws -> Self) -> Self {
        return verifiedPost(do: cont, or: expectedPost)
    }
    
    public static func verifiedPost(do cont: @escaping ([String:String]) throws -> Self, or: @escaping () throws -> Self) -> Self {
        return .withPostData { data in
            if !data.isEmpty, let body = String(data: data, encoding: .utf8)?.parseAsQueryPart {
                return withCSRF { csrf in
                    catchAndDisplayError {
                        guard body["csrf"] == csrf.string else {
                            throw ServerError(privateMessage: "CSRF failure", publicMessage: "Something went wrong.")
                        }
                        return try cont(body)
                    }
                }
            } else {
                return catchAndDisplayError(or)
            }
        }
    }
    
    public static func jsonPost<A: Decodable>(do cont: @escaping (A) throws -> Self, or: @escaping () throws -> Self = expectedPost) -> Self {
        return .withPostData { data in
            if !data.isEmpty {
                let decoder = JSONDecoder()
                return catchAndDisplayError {
                    try cont(try decoder.decode(A.self, from: data))
                }
            } else {
                return catchAndDisplayError(or)
            }
        }
    }
    
    // Renders a form. If it's POST, we try to parse the result and call the `onPost` handler, otherwise (a GET) we render the form.
    public static func form<A, B>(_ f: Form<A, Env>, initial: A, convert: @escaping (A) -> Either<B, [ValidationError]>, onPost: @escaping (B) throws -> Self) -> Self {
        return verifiedPost(do: { (body: [String:String]) -> Self in
            withCSRF { csrf in
                catchAndDisplayError {
                    guard let result = f.parse(body) else { throw ServerError(privateMessage: "Couldn't parse form", publicMessage: "Something went wrong. Please try again.") }
                    switch convert(result) {
                    case let .left(value):
                        return try onPost(value)
                    case let .right(errs):
                        return .write(html: f.render(result, errs), status: .ok)
                    }
                }
            }
        }, or: {
            return .write(html: f.render(initial, []), status: .ok)
        })
        
    }

    public static func form<A>(_ f: Form<A, Env>, initial: A, validate: @escaping (A) -> [ValidationError], onPost: @escaping (A) throws -> Self) -> Self {
        return form(f, initial: initial, convert: { (a: A) -> Either<A, [ValidationError]> in
            let errs = validate(a)
            return errs.isEmpty ? .left(a) : .right(errs)
        }, onPost: onPost)
    }

    public static func write(html: Node<Env>, status: HTTPResponseStatus = .ok) -> Self {
        return .write(html: html, status: status)
    }

    public static func withSession(_ cont: @escaping (Env.S?) throws -> Self) -> Self {
        return withSession { sess in
            catchAndDisplayError { try cont(sess) }
        }
    }
    
    public static func requireSession(_ cont: @escaping (Env.S) throws -> Self) -> Self {
        return withSession { sess in
            catchAndDisplayError {
                try cont(sess ?! AuthorizationError())
            }
        }
    }
}
