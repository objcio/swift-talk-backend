//
//  Circle.swift
//  swifttalk-server
//
//  Created by Florian Kugler on 17-11-2018.
//

import Foundation

let circle = Circle()

struct Circle {
    let base = URL(string: "https://circleci.com/api/v1.1/")!
    var apiKey = env.circleApiKey
    
    var triggerMainSiteBuild: RemoteEndpoint<()> {
        let url = base.appendingPathComponent("project/github/objcio/website/tree/master")
        return RemoteEndpoint<()>(.post, url: url, query: ["circle-token": apiKey])
    }
}
