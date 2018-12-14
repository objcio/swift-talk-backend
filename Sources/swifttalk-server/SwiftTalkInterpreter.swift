//
//  SwiftTalkInterpreter.swift
//  Bits
//
//  Created by Chris Eidhof on 13.12.18.
//

import Foundation
import NIOHTTP1

struct Reader<Value, Result> {
    let run: (Value) -> Result
    
    init(_ run: @escaping (Value) -> Result) {
        self.run = run
    }
    
    static func const(_ value: Result) -> Reader {
        return Reader { _ in value }
    }
}

extension Reader: Interpreter where Result: Interpreter {
    typealias I = Result
    static func write(_ string: String, status: HTTPResponseStatus, headers: [String : String]) -> Reader<Value, Result> {
        return Reader.const(I.write(string, status: status, headers: headers))
    }
    
    static func write(_ data: Data, status: HTTPResponseStatus, headers: [String : String]) -> Reader<Value, Result> {
        return Reader.const(I.write(data, status: status, headers: headers))
    }
    
    static func writeFile(path: String, maxAge: UInt64?) -> Reader<Value, Result> {
        return Reader.const(I.writeFile(path: path, maxAge: maxAge))
    }
    
    static func redirect(path: String, headers: [String : String]) -> Reader<Value, Result> {
        return Reader.const(I.redirect(path: path, headers: headers))
    }
    
    static func onComplete<A>(promise: Promise<A>, do cont: @escaping (A) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { value in I.onComplete(promise: promise, do: { x in
            cont(x).run(value)
        })}
    }
    
    static func withPostData(do cont: @escaping (Data) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { value in I.withPostData(do: { cont($0).run(value) }) }
    }
}

extension Reader: SwiftTalkInterpreter where Result: Interpreter { }

protocol HasSession {
    static func withSession(_ cont: @escaping (Session?) -> Self) -> Self
}

import PostgreSQL
protocol HasDatabase {
    static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) -> Self) -> Self
    @available(*, deprecated) static func withConnection(_ cont: @escaping (Either<PostgreSQL.Connection, Error>) -> Self) -> Self
}

extension Reader: HasDatabase where Value == RequestEnvironment {
    static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) -> Reader<RequestEnvironment, Result>) -> Reader<RequestEnvironment, Result> {
        return Reader { env in
            do {
                return cont(try .left(env.connection().execute(query, loggingTreshold: 0.1))).run(env)
            } catch {
                return cont(.right(error)).run(env)
            }
        }
    }
    
    static func withConnection(_ cont: @escaping (Either<Connection, Error>) -> Reader<RequestEnvironment, Result>) -> Reader<RequestEnvironment, Result> {
        return Reader { env in
            do {
                return cont(.left(try env.connection())).run(env)
            } catch {
                return cont(.right(error)).run(env)
            }
        }
    }
    
}

extension SwiftTalkInterpreter where Self: HTML, Self: HasDatabase {
    static func query<A>(_ query: Query<A>, _ cont: @escaping (A) throws -> Self) -> Self {
        return Self.execute(query) { (result: Either<A, Error>) in
            catchAndDisplayError {
                switch result {
                case let .left(value): return try cont(value)
                case let .right(err): throw err
                }
            }
        }
    }
    
    static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) throws -> Self) -> Self {
        return Self.execute(query) { (result: Either<A, Error>) in
            catchAndDisplayError {
                return try cont(result)
            }
        }

    }
    
    @available(*, deprecated) static func withConnection(_ cont: @escaping (Connection) throws -> Self) -> Self {
        return Self.withConnection { (result: Either<Connection,Error>) in
            catchAndDisplayError {
                switch result {
                case .left(let c): return try cont(c)
                case .right(let e): throw e
                }
            }
        }
    }
}

extension SwiftTalkInterpreter where Self: HasSession, Self: HTML {
    static func requireSession(_ cont: @escaping (Session) throws -> Self) -> Self {
        return withSession { sess in
            catchAndDisplayError {
                try cont(sess ?! AuthorizationError())
            }
        }
    }
}

extension Reader: HasSession where Value == RequestEnvironment {
    static func withSession(_ cont: @escaping (Session?) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { value in
            cont(value.session).run(value)
        }
    }
}

extension SwiftTalkInterpreter where Self: HTML, Self: HasSession {
    static func withSession(_ cont: @escaping (Session?) throws -> Self) -> Self {
        return withSession { sess in
            catchAndDisplayError { try cont(sess) }
        }
    }
}

protocol HTML {
    static func write(_ html: Node, status: HTTPResponseStatus) -> Self
    static func withCSRF(_ cont: @escaping (CSRFToken) -> Self) -> Self
}

extension HTML {
    static func write(_ html: Node) -> Self {
        return self.write(html, status: .ok)
    }
}

extension Reader: HTML where Result: SwiftTalkInterpreter, Value == RequestEnvironment {
    static func write(_ html: Node, status: HTTPResponseStatus) -> Reader {
        return Reader { value in
            return .write(html.htmlDocument(input: value))
        }
    }
    
    static func withCSRF(_ cont: @escaping (CSRFToken) -> Reader) -> Reader {
        return Reader { value in
            return cont(value.context.csrf).run(value)
        }
    }
}


protocol SwiftTalkInterpreter: Interpreter {
    static func writeFile(path: String) -> Self
    static func notFound(_ string: String) -> Self
    static func write(_ string: String, status: HTTPResponseStatus) -> Self
    static func write(rss: ANode<()>, status: HTTPResponseStatus) -> Self
    static func write(json: Data, status: HTTPResponseStatus) -> Self
    static func redirect(to route: Route, headers: [String: String]) -> Self
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
    
    static func write(rss: ANode<()>, status: HTTPResponseStatus = .ok) -> Self {
        return .write(rss.xmlDocument, status: status, headers: ["Content-Type": "application/rss+xml; charset=utf-8"])
    }
    
    static func write(json: Data, status: HTTPResponseStatus = .ok) -> Self {
        return .write(json, status: status, headers: ["Content-Type": "application/json"])
    }
    
    static func redirect(to route: Route, headers: [String: String] = [:]) -> Self {
        return .redirect(path: route.path, headers: headers)
    }
}

extension SwiftTalkInterpreter where Self: HTML {
    static func onSuccess<A>(promise: Promise<A?>, file: StaticString = #file, line: UInt = #line, message: String = "Something went wrong.", do cont: @escaping (A) throws -> Self) -> Self {
        return onSuccess(promise: promise, file: file, line: line, message: message, do: cont, else: {
            throw ServerError(privateMessage: "Expected non-nil value, but got nil (\(file):\(line)).", publicMessage: message)
        })
    }
    
    static func onSuccess<A>(promise: Promise<A?>, file: StaticString = #file, line: UInt = #line, message: String = "Something went wrong.", do cont: @escaping (A) throws -> Self, else: @escaping () throws -> Self) -> Self {
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
    
    static func verifiedPost(do cont: @escaping ([String:String]) throws -> Self) -> Self {
        return verifiedPost(do: cont, or: {
            throw ServerError(privateMessage: "Expected POST", publicMessage: "Something went wrong.")
        })
    }
    static func verifiedPost(do cont: @escaping ([String:String]) throws -> Self, or: @escaping () throws -> Self) -> Self {
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

    static func onCompleteOrCatch<A>(promise: Promise<A>, do cont: @escaping (A) throws -> Self) -> Self {
        return onComplete(promise: promise, do: { value in
            catchAndDisplayError { try cont(value) }
        })
    }

    // Renders a form. If it's POST, we try to parse the result and call the `onPost` handler, otherwise (a GET) we render the form.
    static func form<A,B>(_ f: Form<A>, initial: A, convert: @escaping (A) -> Either<B, [ValidationError]>, onPost: @escaping (B) throws -> Self) -> Self {
        return verifiedPost(do: { body in
            withCSRF { csrf in
            	catchAndDisplayError {
                    guard let result = f.parse(body) else { throw ServerError(privateMessage: "Couldn't parse form", publicMessage: "Something went wrong. Please try again.") }
                    switch convert(result) {
                    case let .left(value):
                        return try onPost(value)
                    case let .right(errs):
                        return .write(f.render(result, errs))
                    }
        		}
            }
        }, or: {
            return .write(f.render(initial, []))
        })
        
    }
    
    static func form<A>(_ f: Form<A>, initial: A, validate: @escaping (A) -> [ValidationError], onPost: @escaping (A) throws -> Self) -> Self {
        return form(f, initial: initial, convert: { (a: A) -> Either<A, [ValidationError]> in
            let errs = validate(a)
            return errs.isEmpty ? .left(a) : .right(errs)
        }, onPost: onPost)
    }
}
