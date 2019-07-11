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
            return I.query(Row<UserData>.select(uuid), { user in
                guard let u = user else { return I.write("no such user") }
                return I.query(u.teamMembers) { members in
                    return I.onSuccess(promise: u.currentSubscription.promise, do: { sub in
                        return I.query(u.teamMemberCountForRecurly) { memberCount in
                            return I.write("\(u.data)\n\n\(members)\n\n\(memberCount)\n\n\(String(describing: sub))")
                        }
                    })
                }
            })
        case let .users(.sync(uuid)):
            return I.query(Row<UserData>.select(uuid), { user in
                guard let u = user else { return I.write("no such user") }
                return I.onSuccess(promise: u.currentSubscription.promise) { sub in
                    guard let s = sub else { return I.write("no sub") }
                    return I.query(u.teamMemberCountForRecurly) { numberOfTeamMembers in
                        let update = recurly.updateSubscription(s, numberOfTeamMembers: numberOfTeamMembers)
                        return I.onSuccess(promise: update.promise, do: { result in
                            return I.write("\(result)\n\n\(update.description)")
                        })
                    }
                }
            })
        }
    }
}
