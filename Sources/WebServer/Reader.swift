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

extension Reader: NIOWrapper.Response where Result: NIOWrapper.Response {
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
        return Reader { value in .withPostData(do: { cont($0).run(value) }) }
    }
}

extension Reader: Response where Result: Response {}

extension Reader: ResponseRequiringEnvironment where Result: Response, Value: RequestEnvironment {
    public typealias Env = Value
    
    public static func withSession(_ cont: @escaping (Env.S?) -> Reader<Value, Result>) -> Reader<Value, Result> {
        return Reader { value in
            cont(value.session).run(value)
        }
    }
    
    /*
    public static func write(html: Node<Env>, status: HTTPResponseStatus = .ok) -> Reader<Value, Result> {
        return Reader { (value: Value) -> Result in
            let rendered = measure(message: "render html") { html.htmlDocument(input: value) }
            return Result.write(rendered, status: status, headers: ["Content-Type": "text/html; charset=utf-8"])
        }
    }
 */
    
    public static func write(html: Reader<Value, RenderedHTML>, status: HTTPResponseStatus = .ok) -> Reader<Value, Result> {
        return Reader { (value: Value) -> Result in
            let rendered = measure(message: "render html") { html.run(value).string } // todo prepend doc start
            return Result.write(rendered, status: status, headers: ["Content-Type": "text/html; charset=utf-8"])
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
