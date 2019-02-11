//
//  Sendgrid.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 06-12-2018.
//

import Foundation
import Networking

let sendgrid = Sendgrid()

struct Sendgrid {
    let base = URL(string: "https://api.sendgrid.com/v3")!
    let apiKey = env.sendgridApiKey
    var headers: [String:String] {
        return [
            "Authorization": "Bearer \(apiKey)"
        ]
    }

    func send(to email: String, name: String, subject: String, text: String) -> RemoteEndpoint<()> {
        struct Payload: Codable {
            struct Person: Codable {
                var email: String
                var name: String
            }
            struct Personalization: Codable {
                var to: [Person]
                var subject: String
            }
            struct Content: Codable {
                var type: String
                var value: String
            }
            var personalizations: [Personalization]
            var from: Person
            var content: [Content]
        }
        let url = base.appendingPathComponent("mail/send")
        let objcio = Payload.Person(email: emailFrom, name: emailName)
        let body = Payload(personalizations: [Payload.Personalization(to: [Payload.Person(email: email, name: name)], subject: subject)], from: objcio, content: [Payload.Content(type: "text/plain", value: text)])
        if apiKey == "test" {
//            dump(body)
        }
        return RemoteEndpoint(json: .post, url: url, body: body, headers: headers)
    }
}
