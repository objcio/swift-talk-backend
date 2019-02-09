//
//  Reader.swift
//  WebServer
//
//  Created by Florian Kugler on 09-02-2019.
//

import Foundation
import Base
import NIOWrapper
import HTML
import Database
import Promise


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

extension Reader: Response where Result: Response, Value: RequestEnvironment {}

extension Reader: ResponseRequiringEnvironment where Result: Response, Value: RequestEnvironment {
    public typealias Env = Value
    
    public static func renderError(_ error: Error) -> Reader<Value, Result> {
        fatalError()
    }
    
    public static func withSession(_ cont: @escaping (Env.S?) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { value in
            cont(value.session).run(value)
        }
    }
    
    public static func write(html: Node<Env>, status: HTTPResponseStatus = .ok) -> Reader<Value, Result> {
        return Reader { (value: Value) -> Result in
            return Result.write(html: html.ast(input: value), status: status)
        }
    }
    
    public static func withCSRF(_ cont: @escaping (CSRFToken) -> Reader) -> Reader {
        return Reader { (value: Value) in
            return cont(value.csrf).run(value)
        }
    }
    
    public static func execute<A>(_ query: Query<A>, _ cont: @escaping (Either<A, Error>) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { env in
            return cont(env.execute(query)).run(env)
        }
    }
}
