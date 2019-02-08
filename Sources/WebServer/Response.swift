//
//  SwiftTalkInterpreter.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import Promise
import NIOWrapper
import HTML
import Database
import Base


public struct ServerError: LocalizedError {
    /// Private message for logging
    public let privateMessage: String
    /// Message shown to the user
    public let publicMessage: String
    
    public init(privateMessage: String, publicMessage: String) {
        self.privateMessage = privateMessage
        self.publicMessage = publicMessage
    }
    
    public var errorDescription: String? {
        return "ServerError: \(privateMessage)"
    }
}

public struct AuthorizationError: Error { }


public struct Reader<Value, Result> {
    public let run: (Value) -> Result
    
    public init(_ run: @escaping (Value) -> Result) {
        self.run = run
    }
    
    public static func const(_ value: Result) -> Reader {
        return Reader { _ in value }
    }
}

extension Reader: NIOWrapper.Response where Result: NIOWrapper.Response {
    typealias I = Result
    public static func write(_ string: String, status: HTTPResponseStatus, headers: [String : String]) -> Reader<Value, Result> {
        return .const(.write(string, status: status, headers: headers))
    }
    
    public static func write(_ data: Data, status: HTTPResponseStatus, headers: [String : String]) -> Reader<Value, Result> {
        return .const(.write(data, status: status, headers: headers))
    }
    
    public static func writeFile(path: String, maxAge: UInt64?) -> Reader<Value, Result> {
        return .const(.writeFile(path: path, maxAge: maxAge))
    }
    
    public static func redirect(path: String, headers: [String : String]) -> Reader<Value, Result> {
        return .const(.redirect(path: path, headers: headers))
    }
    
    public static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { value in .onComplete(promise: promise, do: { x in
            cont(x).run(value)
        })}
    }
    
    public static func withPostData(do cont: @escaping (Data) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { value in I.withPostData(do: { cont($0).run(value) }) }
    }
}


public protocol Response: NIOWrapper.Response {
    associatedtype R: RouteP
    associatedtype S: SessionP
    typealias RE = RequestEnvironment<R, S>
    static func write(_ string: String, status: HTTPResponseStatus) -> Self
    static func write(html: ANode<()>, status: HTTPResponseStatus) -> Self
    static func write(rss: ANode<()>, status: HTTPResponseStatus) -> Self
    static func write(json: Data, status: HTTPResponseStatus) -> Self
    static func redirect(to R: R, headers: [String: String]) -> Self
    static func renderError(_ error: Error) -> Self
}

public protocol ResponseRequiringEnvironment: Response {
    static func write(html: ANode<RE>, status: HTTPResponseStatus) -> Self
    static func withCSRF(_ cont: @escaping (CSRFToken) -> Self) -> Self
    static func withSession(_ cont: @escaping (S?) -> Self) -> Self
    static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) -> Self) -> Self
}


extension Response {
    public static func writeFile(path: String, maxAge: UInt64? = 60) -> Self {
        return .writeFile(path: path, maxAge: maxAge)
    }
    
    public static func write(_ string: String, status: HTTPResponseStatus = .ok) -> Self {
        return .write(string, status: status, headers: ["Content-Type": "text/plain; charset=utf-8"])
    }
    
    public static func write(html: ANode<()>, status: HTTPResponseStatus = .ok) -> Self {
        return .write(html.htmlDocument(input: ()), status: status, headers: ["Content-Type": "text/html; charset=utf-8"])
    }
    
    public static func write(rss: ANode<()>, status: HTTPResponseStatus = .ok) -> Self {
        return .write(rss.xmlDocument, status: status, headers: ["Content-Type": "application/rss+xml; charset=utf-8"])
    }
    
    public static func write(json: Data, status: HTTPResponseStatus = .ok) -> Self {
        return .write(json, status: status, headers: ["Content-Type": "application/json"])
    }
    
    public static func redirect(to route: R, headers: [String: String] = [:]) -> Self {
        return .redirect(path: route.path, headers: headers)
    }
    
    public static func renderError(_ error: Error) -> Self {
        return .write("Server Error: \(String(describing: error))", status: .internalServerError)
    }

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

extension ResponseRequiringEnvironment {
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

    public static func verifiedPost(do cont: @escaping ([String:String]) throws -> Self) -> Self {
        return verifiedPost(do: cont, or: {
            throw ServerError(privateMessage: "Expected POST", publicMessage: "Something went wrong.")
        })
    }
    
    public static func verifiedPost(do cont: @escaping ([String:String]) throws -> Self, or: @escaping () throws -> Self) -> Self {
        return .withPostData { data in
            if !data.isEmpty, let body = String(data: data, encoding: .utf8)?.parseAsQueryPart {
                return withCSRF { csrf in
                    catchAndDisplayError {
                        guard body["csrf"] == csrf.stringValue else {
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
    
    // Renders a form. If it's POST, we try to parse the result and call the `onPost` handler, otherwise (a GET) we render the form.
    public static func form<A,B>(_ f: Form<A, RequestEnvironment<R, S>>, initial: A, convert: @escaping (A) -> Either<B, [ValidationError]>, onPost: @escaping (B) throws -> Self) -> Self {
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

    public static func form<A>(_ f: Form<A, RequestEnvironment<R, S>>, initial: A, validate: @escaping (A) -> [ValidationError], onPost: @escaping (A) throws -> Self) -> Self {
        return form(f, initial: initial, convert: { (a: A) -> Either<A, [ValidationError]> in
            let errs = validate(a)
            return errs.isEmpty ? .left(a) : .right(errs)
        }, onPost: onPost)
    }

    public static func write(html: ANode<RE>, status: HTTPResponseStatus = .ok) -> Self {
        return .write(html: html, status: status)
    }

    public static func withSession(_ cont: @escaping (S?) throws -> Self) -> Self {
        return withSession { sess in
            catchAndDisplayError { try cont(sess) }
        }
    }
    
    public static func requireSession(_ cont: @escaping (S) throws -> Self) -> Self {
        return withSession { sess in
            catchAndDisplayError {
                try cont(sess ?! AuthorizationError())
            }
        }
    }
}

extension Reader: Response where Result: Response, Value == RequestEnvironment<Result.R, Result.S> {}

extension Reader: ResponseRequiringEnvironment where Result: Response, Value == RequestEnvironment<Result.R, Result.S> {
    public typealias R = Result.R
    public typealias S = Result.S

    public static func renderError(_ error: Error) -> Reader<Value, Result> {
        fatalError()
    }
    
    public static func withSession(_ cont: @escaping (Result.S?) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { value in
            cont(value.session).run(value)
        }
    }

    public static func write(html: ANode<RE>, status: HTTPResponseStatus = .ok) -> Reader<Value, Result> {
        return Reader { (value: Value) -> Result in
            return Result.write(html: html.ast(input: value), status: status)
        }
    }
    
    public static func withCSRF(_ cont: @escaping (CSRFToken) -> Reader) -> Reader {
        return Reader { (value: Value) in
            return cont(value.context.csrf).run(value)
        }
    }

    public static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { env in
            return cont(env.execute(query)).run(env)
        }
    }
}
