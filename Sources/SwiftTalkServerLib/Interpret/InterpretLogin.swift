//
//  InterpretLogin.swift
//  SwiftTalkServerLib
//
//  Created by Florian Kugler on 01-02-2019.
//

import Foundation
import Base
import Database
import WebServer


extension Route.Login {
    func interpret<I: ResponseRequiringEnvironment>() throws -> I {
        switch self {
        
        case .login(let cont):
            var path = "https://github.com/login/oauth/authorize?scope=user:email&client_id=\(github.clientId)"
            if let c = cont {
                let encoded = env.baseURL.absoluteString + Route.login(.githubCallback(code: nil, origin: c.path)).path
                path.append("&redirect_uri=" + encoded.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)
            }
            return .redirect(path: path, headers: [:])
        
        case .githubCallback(let optionalCode, let origin):
            guard let code = optionalCode else {
                throw ServerError(privateMessage: "No auth code", publicMessage: "Something went wrong, please try again.")
            }
            let loadToken = github.getAccessToken(code).promise.map({ $0?.access_token })
            return .onCompleteOrCatch(promise: loadToken, do: { token in
                let t = try token ?! ServerError(privateMessage: "No github access token", publicMessage: "Couldn't access your Github profile.")
                let loadProfile = Github(accessToken: t).profile.promise
                return .onSuccess(promise: loadProfile, message: "Couldn't access your Github profile", do: { profile in
                    let uid: UUID
                    return .query(Row<UserData>.select(githubId: profile.id)) {
                        func createSession(uid: UUID) -> I {
                            return .query(SessionData(userId: uid).insert) { sid in
                                let destination: String
                                if let o = origin?.removingPercentEncoding, o.hasPrefix("/") {
                                    destination = o
                                } else {
                                    destination = "/"
                                }
                                return .redirect(path: destination, headers: ["Set-Cookie": "sessionid=\"\(sid.uuidString)\"; HttpOnly; Path=/"]) // TODO secure
                            }
                        }
                        if let user = $0 {
                            return createSession(uid: user.id)
                        } else {
                            let userData = UserData(email: profile.email ?? "", githubUID: profile.id, githubLogin: profile.login, githubToken: t, avatarURL: profile.avatar_url, name: profile.name ?? "")
                            return .query(userData.insert, createSession)
                        }
                        
                        
                    }
                })
            })
        }
    }
}
