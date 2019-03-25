import Foundation
import Base
import Database
import WebServer

extension Route.Admin {
    func interpret<I: STResponse>() throws -> I where I.Env == STRequestEnvironment {
        return .requireSession { sess in
            guard sess.user.data.isAdmin else {
                throw ServerError(privateMessage: "Not an admin")
            }
            return try self.interpret(sesssion: sess)
        }
    }
    
    private func interpret<I: STResponse>(sesssion sess: Session) throws -> I where I.Env == STRequestEnvironment {
        switch self {
        case .home:
            return I.write("Home")
        case .users(.home):
            return I.write("Users")
        case .users(.find(let searchString)):
            return I.write("Find: \(searchString)")
        case let .users(.view(uuid)):
            return I.write("User: \(uuid)")
        }
    }
}
