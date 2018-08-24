import Foundation
import NIO
import NIOHTTP1
import PostgreSQL


var standardError = FileHandle.standardError
let env = Env()

let recurly = Recurly(subdomain: "\(env["RECURLY_SUBDOMAIN"]).recurly.com", apiKey: env["RECURLY_API_KEY"])

// TODO: I'm not sure if it's a good idea to initialize the plans like this. We should maybe also have static data?
private(set) var plans: [Plan] = []
URLSession.shared.load(recurly.plans, callback: { value in
    if let p = value {
        plans = p
    } else {
        print("Could not load plans", to: &standardError) // todo: fall back to old plans?
    }
})

// fetches mail@floriankugler.com account from recurly staging and calculates number of months with an active subscription
//let myId = UUID(uuidString: "06a5313b-7972-48a9-a0a9-3d7d741afe44")!
//URLSession.shared.load(recurly.account(with: myId)) { result in
//    guard let acc = result else { fatalError() }
//    URLSession.shared.load(recurly.listSubscriptions(accountId: acc.account_code)) { subs in
//        let months = subs?.map { $0.activeMonths }.reduce(0, +)
//        print("Months of active subscription: \(months)")
//    }
//}

func log(_ e: Error) {
    print(e.localizedDescription, to: &standardError)
}

func log(error: String) {
    print(error, to: &standardError)
}

struct NoDatabaseConnection: Error { }

let currentDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcePaths = [currentDir.appendingPathComponent("assets"), currentDir.appendingPathComponent("node_modules")]

runMigrations()
loadStaticData()

let s = MyServer(handle: { request in
    guard let route = Route(request) else { return nil }
    let sessionString = request.cookies.first { $0.0 == "sessionid" }?.1
    let sessionId = sessionString.flatMap { UUID(uuidString: $0) }
    let conn = Lazy<Connection>({ () throws -> Connection in
        let c: Connection? = postgreSQL.flatMap {
            do {
                let conn = try $0.makeConnection()
                return conn
            } catch {
                print(error, to: &standardError)
                print(error.localizedDescription, to: &standardError)
                return nil
            }
        }
        if let conn = c {
            return conn
        } else {
            throw NoDatabaseConnection()
        }
    }, cleanup: { conn in
        try? conn.close()
    })
    return catchAndDisplayError {
        return try route.interpret(sessionId: sessionId, connection: conn)
    }
}, resourcePaths: resourcePaths)
try s.listen()


